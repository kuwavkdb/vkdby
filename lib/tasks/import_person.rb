# frozen_string_literal: true

# Usage: ID=15962 PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails runner lib/tasks/import_person.rb

require_relative 'wikipage_parser'

# Define Wikipage model temporarily
class Wikipage < ActiveRecord::Base
end

wikipage_id = ENV['ID']
unless wikipage_id
  puts 'Please provide ID environment variable. e.g. ID=15962'
  exit 1
end

# 1. Fetch Wikipage
wp = Wikipage.find_by(id: wikipage_id)
unless wp
  puts "No Wikipage found for id=#{wikipage_id}"
  exit 1
end

wiki_content = wp.wiki
attributes = wp.attributes.slice('dw_id', 'it_id', 'eplus_id')
wikipage_name = wp.name

puts "Fetched Wikipage: #{wikipage_name} (ID: #{wikipage_id}, Content size: #{wiki_content&.size})"

unless wiki_content
  puts 'No valid content.'
  exit
end

# Remove comment lines (lines starting with //)
wiki_content = wiki_content.lines.reject { |line| line.strip.start_with?('//') }.join

ActiveRecord::Base.transaction do
  # 2. Parse Person Data
  # Parse person name and kana from Wikipage title
  # Format: "Name (Kana)" or "Name"
  if wp.title =~ /^(.+?)[（(](.+?)[）)]/
    person_name = Regexp.last_match(1).strip
    person_name_kana = Regexp.last_match(2).strip
  else
    person_name = wp.title.strip
    person_name_kana = nil
  end

  # Parse history from first line: "OldName(Kana) → NewName(Kana)"
  first_line = wiki_content.lines.first&.strip&.gsub(/^!+/, '')&.strip
  name_log_entries = []

  if first_line&.include?('→')
    puts "Found history definition in first line: #{first_line}"
    parts = first_line.split('→').map(&:strip)
    parsed_names = parts.map do |part|
      if part =~ /^(.+?)\s*[（(](.+)[）)]$/
        { name: Regexp.last_match(1).strip, name_kana: Regexp.last_match(2).strip }
      else
        { name: part, name_kana: nil }
      end
    end

    # The last one is the current name (override title parsing if present)
    current_person_data = parsed_names.last
    person_name = current_person_data[:name]
    person_name_kana = current_person_data[:name_kana]

    # Store all names in log including the current one
    name_log_entries = parsed_names
  end

  # Encode old_key to EUC-JP URL (Store encoded string)
  encoded_old_key = WikipageParser::Utils.encode_euc_jp_url(wikipage_name)

  # 3. Parse Categories (before key generation to use birthday for uniqueness)
  categories = WikipageParser::CategoryParser.parse_categories(wiki_content)

  # Check if this is a person page
  unless categories[:is_person]
    puts 'Skipping: Not a person page (no {{category 個人}} found)'
    exit 0
  end

  # Generate person_key (URL key for this app) with birthday for uniqueness
  person_key = WikipageParser::Utils.generate_person_key(
    wikipage_name,
    person_name,
    person_name_kana,
    birthday_month: categories[:birthday_month],
    birthday_day: categories[:birthday_day]
  )

  puts "Target Person: #{person_name} (Kana: #{person_name_kana}, Key: #{person_key}, Old Key: #{encoded_old_key})"

  # Find or create Person
  # Try to find by old_key first (for existing records), then by key
  person = Person.find_by(old_key: wikipage_name) ||
           Person.find_by(old_key: encoded_old_key) ||
           Person.find_or_initialize_by(key: person_key)

  # Set basic attributes
  person.key = person_key if person.new_record? # Only set key for new records
  person.name = person_name
  person.name_kana = person_name_kana
  person.name_log = name_log_entries if name_log_entries.present?
  person.old_key = encoded_old_key
  person.old_wiki_text = wiki_content

  # Set status based on categories (priority order: passed_away > retired > free > active)
  if categories[:is_passed_away]
    person.status = :passed_away
    puts '  Status: Passed Away'
  elsif categories[:is_unknown]
    person.status = :unknown
    puts '  Status: Unknown'
  elsif categories[:is_retired]
    person.status = :retirement
    puts '  Status: Retirement'
  elsif categories[:is_free]
    person.status = :free
    puts '  Status: Free'
  else
    person.status = :active
  end

  # Set birthday
  if categories[:birthday_month] && categories[:birthday_day]
    person.birthday = Date.new(1904, categories[:birthday_month], categories[:birthday_day])
    puts "  Birthday: #{categories[:birthday_month]}/#{categories[:birthday_day]}"
  end

  # Set birth year
  if categories[:birth_year]
    person.birth_year = categories[:birth_year]
    puts "  Birth Year: #{categories[:birth_year]}"
  elsif categories[:birth_year_unknown]
    person.birth_year = nil
    puts '  Birth Year: Unknown'
  end

  # Set blood type
  if categories[:blood]
    person.blood = categories[:blood]
    puts "  Blood Type: #{categories[:blood]}"
  end

  # Set hometown
  if categories[:hometown]
    person.hometown = categories[:hometown]
    puts "  Hometown: #{categories[:hometown]}"
  end

  # Set parts
  if categories[:parts].any?
    person.parts = categories[:parts]
    puts "  Parts: #{categories[:parts].join(', ')}"
  end

  person.save!
  puts "Person saved: #{person.name} (id: #{person.id})"

  # 4. Parse Links (only from !!リンク section)
  # Extract !!リンク section content
  link_section_content = if wiki_content =~ /!!リンク\s*\n(.+?)(?=\n!!|\z)/m
                           Regexp.last_match(1).strip
                         else
                           '' # No link section found
                         end

  if link_section_content.present?
    # 4.1. Unlink Plugin (Inactive Links) - only within link section
    unlink_regex = /\{\{unlink\s+(.*?)\}\}/m

    puts 'Scanning for unlink blocks in link section...'
    link_section_content.scan(unlink_regex).each do |match|
      puts 'Found unlink block!'
      unlink_content = match[0]
      WikipageParser::LinkParser.parse_links(person, unlink_content, attributes, active: false)
    end

    # 4.2. Active Links (Remove unlink blocks first) - only within link section
    active_content = link_section_content.gsub(unlink_regex, '')
    puts 'Parsing active links from link section...'
    WikipageParser::LinkParser.parse_links(person, active_content, attributes, active: true)
  else
    puts 'No !!リンク section found, skipping link parsing'
  end

  # 5. Parse Career History (経歴)
  # Format: → [[Unit Name]](Part) → [[Another Unit]](Part) →
  if wiki_content =~ /!!経歴\s*\n(.+?)(?=\n!!|\z)/m
    career_section = Regexp.last_match(1).strip

    # Save career section to old_history
    person.old_history = career_section
    person.save!

    puts "\nParsing career history..."
    puts "Career section: #{career_section[0..200]}..."

    # Extract unit references: [[Unit Name]](Part)
    career_section.scan(/→\s*\[\[([^\]]+)\]\](?:\(([^)]+)\))?/).each do |unit_name, part_str|
      unit_name = unit_name.strip
      part_str = part_str&.strip

      puts "  Found career entry: Unit=#{unit_name}, Part=#{part_str}"

      # Try to find the unit by name
      unit = Unit.find_by(name: unit_name)

      if unit
        puts "    Found unit: #{unit.name} (id: #{unit.id})"

        # Check if UnitPerson already exists
        unit_person = UnitPerson.find_or_initialize_by(unit: unit, person: person)

        # Parse part
        if part_str
          part_key = case part_str.downcase
                     when /vocal/ then :vocal
                     when /guitar/ then :guitar
                     when /bass/ then :bass
                     when /drums/ then :drums
                     when /keyboard/ then :keyboard
                     when /dj/ then :dj
                     else :unknown
                     end

          unit_person.part = part_key if unit_person.new_record?
        end

        unit_person.status = :left # Historical membership
        unit_person.save!
        puts '    UnitPerson created/updated'
      else
        puts "    Unit not found: #{unit_name} (skipping)"
      end
    end
  end
end

puts "\nDone!"

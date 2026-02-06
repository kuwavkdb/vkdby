# frozen_string_literal: true

require 'romaji'

# rubocop:disable Metrics/ClassLength, Metrics/AbcSize, Metrics/PerceivedComplexity
class PersonImporter < BaseWikipageImporter
  def self.import(wikipage)
    new(wikipage).import
  end

  def self.valid_person?(wikipage)
    return false if ignored?(wikipage)

    wikipage.wiki&.include?('{{category 個人')
  end

  protected

  def process_import
    import_person
  end

  private

  def import_person
    # 1. Parse Person Data
    title = @wikipage.title.to_s.strip
    if title =~ /^(.+?)[（(](.+?)[）)]/
      raw_name = Regexp.last_match(1).strip
      person_name = extract_name_from_wiki_link(raw_name)
      person_name_kana = Regexp.last_match(2).strip
    else
      person_name = extract_name_from_wiki_link(title)
      person_name_kana = nil
    end

    # Parse history from first line: "OldName(Kana) → NewName(Kana)"
    first_line = @wiki_content.lines.first&.strip&.gsub(/^!+/, '')&.strip
    name_log_entries = []

    if first_line&.include?('→')
      parts = first_line.split('→').map(&:strip)
      parsed_names = parts.map do |part|
        if part =~ /\{\{rb\s+(.+?),\s*(.+?)\}\}/
          raw_name = Regexp.last_match(1).strip
          { name: extract_name_from_wiki_link(raw_name), name_kana: Regexp.last_match(2).strip }
        elsif part =~ /^(.+?)\s*[（(](.+)[）)]$/
          raw_name = Regexp.last_match(1).strip
          { name: extract_name_from_wiki_link(raw_name), name_kana: Regexp.last_match(2).strip }
        else
          { name: extract_name_from_wiki_link(part), name_kana: nil }
        end
      end

      # The last one is the current name
      current_person_data = parsed_names.last
      person_name = current_person_data[:name]
      person_name_kana = current_person_data[:name_kana]
      name_log_entries = parsed_names
    end

    encoded_old_key = URI.encode_www_form_component(@wikipage_name.encode('EUC-JP'))

    # 2. Parse Categories
    categories_data = parse_categories_data

    # Generate person_key
    person_key = generate_person_key(
      @wikipage_name,
      person_name,
      person_name_kana,
      encoded_old_key,
      birthday_month: categories_data[:birthday_month],
      birthday_day: categories_data[:birthday_day]
    )

    # Find or create Person
    person = Person.find_by(old_key: @wikipage_name) ||
             Person.find_by(old_key: encoded_old_key) ||
             Person.find_or_initialize_by(key: person_key)

    # Set attributes
    person.key = person_key if person.new_record?
    person.name = person_name
    person.name_kana = person_name_kana
    person.name_log = name_log_entries if name_log_entries.present?
    person.old_key = encoded_old_key
    person.old_wiki_id = @wikipage.id
    person.old_wiki_text = @wiki_content

    # Status
    person.status = if categories_data[:is_passed_away]
                      :passed_away
                    elsif categories_data[:is_unknown]
                      :unknown
                    elsif categories_data[:is_retired]
                      :retirement
                    elsif categories_data[:is_free]
                      :free
                    else
                      :active
                    end

    # Attributes from categories
    if categories_data[:birthday_month] && categories_data[:birthday_day]
      if Date.valid_date?(1904, categories_data[:birthday_month], categories_data[:birthday_day])
        person.birthday = Date.new(1904, categories_data[:birthday_month], categories_data[:birthday_day])
      else
        puts "Warning: Invalid birthday for #{person_name} (ID: #{@wikipage.id}): #{categories_data[:birthday_month]}/#{categories_data[:birthday_day]}"
      end
    end

    if categories_data[:birth_year]
      person.birth_year = categories_data[:birth_year]
    elsif categories_data[:birth_year_unknown]
      person.birth_year = nil
    end

    person.blood = categories_data[:blood] if categories_data[:blood]
    person.hometown = categories_data[:hometown] if categories_data[:hometown]
    person.parts = categories_data[:parts] if categories_data[:parts].any?

    # Save Person
    person.save!

    # 2.5 Link existing UnitPerson records
    link_existing_unit_people(person)

    # 3. Associate TagIndex (Categories)
    update_tag_indices(person, categories_data[:raw_categories])

    # 4. Parse Links
    parse_footer_links(person)
    parse_youtube_tags(person)

    # 5. Parse Career History
    parse_career_history(person)

    # 6. Parse Sections
    parse_sections(person)
  end

  def link_existing_unit_people(person)
    return if person.old_key.blank?

    UnitPerson.where(old_person_key: person.old_key).update_all(person_id: person.id, person_key: person.key)
  end

  def parse_categories_data
    categories = { raw_categories: [], parts: [] }

    # Extract all categories first
    category_regex = /\{\{category\s+(.*?)\}\}/i
    @wiki_content.scan(category_regex) do |match|
      content = match[0]
      content.split(',').each do |cat|
        clean_cat = cat.strip
        categories[:raw_categories] << clean_cat

        # Parse specific attributes
        case clean_cat
        when %r{^誕生日/(\d+)/(\d+)$}
          categories[:birthday_month] = Regexp.last_match(1).to_i
          categories[:birthday_day] = Regexp.last_match(2).to_i
        when %r{^誕生年/(\d+)$}
          categories[:birth_year] = Regexp.last_match(1).to_i
        when '誕生年/不明'
          categories[:birth_year_unknown] = true
        when %r{^血液型/([ABABO]+)$}
          categories[:blood] = Regexp.last_match(1)
        when '血液型/不明'
          categories[:blood] = 'Unknown'
        when %r{^出身地/(.+?)$}
          hometown = Regexp.last_match(1)
          categories[:hometown] = hometown unless hometown == '不明'
        when '引退'
          categories[:is_retired] = true
        when '個人/フリー'
          categories[:is_free] = true
        when '死去'
          categories[:is_passed_away] = true
        when '個人/状況不明'
          categories[:is_unknown] = true
        else
          # Check parts
          Person::AVAILABLE_PARTS.each do |part|
            categories[:parts] << part.downcase if clean_cat.casecmp(part).zero?
          end
        end
      end
    end
    categories
  end

  def update_tag_indices(person, raw_categories)
    return unless raw_categories.any?

    # We want to associate ALL categories as tags
    person.tag_index_items.destroy_all

    raw_categories.each do |cat_raw|
      # Skip birthday/birthyear tags as they are better stored as attributes
      next if cat_raw.match?(%r{^(誕生日|誕生年)/})

      # Normalize category name
      index_name = cat_raw.strip

      tag_index = TagIndex.find_or_create_by(name: index_name)
      TagIndexItem.create!(
        tag_index: tag_index,
        indexable: person
      )
    end
  end

  # rubocop:disable Metrics/ParameterLists
  def generate_person_key(wikipage_name, person_name, person_name_kana, encoded_old_key, birthday_month: nil, birthday_day: nil)
    # rubocop:enable Metrics/ParameterLists
    source_for_key = wikipage_name

    if wikipage_name.match?(/^[[:ascii:]\s-]+$/)
      source_for_key = wikipage_name
    elsif person_name_kana.present?
      source_for_key = Romaji.kana2romaji(person_name_kana)
    else
      romaji_attempt = Romaji.kana2romaji(person_name)
      source_for_key = if romaji_attempt.match?(/[^[:ascii:]]/)
                         encoded_old_key.gsub(/%/, '')
                       else
                         romaji_attempt
                       end
    end

    # Replace any non-alphanumeric character (except -) with -
    base_key = source_for_key.downcase.gsub(/[^a-z0-9-]+/, '-').gsub(/-+/, '-')

    if birthday_month && birthday_day
      birthday_suffix = format('%02d%02d', birthday_month, birthday_day)
      "#{base_key}-#{birthday_suffix}"
    else
      base_key
    end
  end

  def parse_footer_links(person)
    link_section_content = if @wiki_content =~ /!!リンク\s*\n(.+?)(?=\n!!|\z)/m
                             Regexp.last_match(1).strip
                           else
                             ''
                           end

    return unless link_section_content.present?

    unlink_regex = /\{\{unlink\s+(.*?)\}\}/m
    link_section_content.scan(unlink_regex).each do |match|
      unlink_content = match[0]
      parse_wiki_links(person, unlink_content, false)
    end

    active_content = link_section_content.gsub(unlink_regex, '')
    parse_wiki_links(person, active_content, true)
  end

  def parse_career_history(person)
    return unless @wiki_content =~ /!!経歴\s*\n(.+?)(?=\n!!|\z)/m

    career_section = Regexp.last_match(1).strip
    person.old_history = career_section
    person.save!

    career_section.scan(/→\s*\[\[([^\]]+)\]\](?:\(([^)]+)\))?/).each do |unit_name, part_str|
      unit_name = unit_name.strip
      part_str = part_str&.strip

      unit = Unit.find_by(name: unit_name)
      next unless unit

      unit_person = UnitPerson.find_or_initialize_by(unit: unit, person: person)

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

      unit_person.status = :left
      unit_person.save!
    end
  end

  def extract_name_from_wiki_link(str)
    # Handle [[Display|Link]] or [[Link]]
    if str =~ /\[\[(?:([^|\]]+)\|)?([^\]]+)\]\]/
      str.gsub(/\[\[(?:([^|\]]+)\|)?([^\]]+)\]\]/) do
        Regexp.last_match(1) || Regexp.last_match(2)
      end
    else
      str
    end
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/AbcSize, Metrics/PerceivedComplexity

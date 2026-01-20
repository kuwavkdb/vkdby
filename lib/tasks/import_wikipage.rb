# Usage: ID=30 PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails runner lib/tasks/import_wikipage.rb

# Define Wikipage model temporarily
class Wikipage < ActiveRecord::Base
end

wikipage_id = ENV['ID']
unless wikipage_id
  puts "Please provide ID environment variable. e.g. ID=30"
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
  puts "No valid content."
  exit
end

require 'romaji'

ActiveRecord::Base.transaction do
  # 2. Derive Unit Data
  # Parse unit name and kana first needed for Logic
  first_line = wiki_content.lines.first.strip
  unit_name_kana = nil

  if first_line.start_with?("!!!")
    # Extract Kana from last parenthesis
    if first_line =~ /[（\(]([^（\(）\)]+)[）\)]\s*$/
      unit_name_kana = $1
    end

    # Remove !!! and everything after first parenthese if present for Name
    unit_name_raw = first_line.sub(/^!!!/, '')
    if unit_name_raw =~ /^(.+?)[（\(]/
      unit_name = $1.strip
    else
      unit_name = unit_name_raw.strip
    end
  else
    unit_name = wp.title.gsub(/\(.+\)/, '').strip # fallback
  end

  # Encode old_key to EUC-JP URL (Store encoded string)
  # Use wikipage_name as source for vkdb.jp link
  encoded_old_key = URI.encode_www_form_component(wikipage_name.encode("EUC-JP"))
  
  # Generate unit_key (URL key for this app)
  # 1. Use wikipage_name if ascii alphanumeric
  # 2. Use unit_name_kana -> Romaji if available
  # 3. Fallback to encoded_old_key or something safe? (Lets assume kana exists for non-ascii)

  source_for_key = wikipage_name
  if wikipage_name.match?(/^[[:ascii:]\s-]+$/)
    # Ascii only
    source_for_key = wikipage_name
  elsif unit_name_kana.present?
    # Convert Kana to Romaji
    source_for_key = Romaji.kana2romaji(unit_name_kana)
  else
    # Fallback: Can't convert safely without kana. Use encoded? Or try to convert name?
    # Romaji gem might handle Kanji? No, usually expect Kana.
    # Just use encoded old key as fallback? No readability.
    # Let's try name as is (Rails param handling might percent encode it)
    source_for_key = wikipage_name
  end

  unit_key = source_for_key.downcase.gsub(/\s+/, '-')
  
  # Important: When we look up by old_key to find existing record, we must use the ENCODED version now if we updated,
  # OR the original string if it wasn't migrated yet.
  # This is tricky. If we just changed current behavior, existing records have uncompressed 'SuG' or 'THE MADNA' or '鯨骨生物群集'.
  # We want to update them to encoded version.
  # So we should try to find by `old_key: wikipage_name` (old behavior) OR `old_key: encoded_old_key` (new behavior).
  
  unit = Unit.find_by(old_key: wikipage_name) || Unit.find_by(old_key: encoded_old_key) || Unit.find_or_initialize_by(key: unit_key)
  
  puts "Target Unit: #{unit_name} (Kana: #{unit_name_kana}, Key: #{unit_key}, Old Key: #{encoded_old_key})"

  unit.key = unit_key
  unit.name = unit_name
  unit.name_kana = unit_name_kana
  unit.old_key = encoded_old_key # Save ENCODED string
  unit.status = :active 
  unit.save!
  puts "Unit saved: #{unit.name} (id: #{unit.id})"

  # 3. Parse Members
  member_regex = /\{\{member2?\s+([^,]+),([^,}\n]+)/
  wiki_content.scan(member_regex).each do |part_str, name_str|
    part_str = part_str.strip
    name_str = name_str.strip
    
    # Map Part
    part_key = case part_str.downcase
               when 'vocal' then :vocal
               when 'guitar' then :guitar
               when 'bass' then :bass
               when 'drums' then :drums
               when 'keyboard' then :keyboard
               when 'dj' then :dj
               else :unknown
               end
    
    # Create Person
    # Use unit_key prefix for uniqueness
    person_key = "#{unit_key}_#{name_str.downcase.gsub(/\s+/, '-')}"
    person = Person.find_or_initialize_by(key: person_key)
    if person.new_record?
      person.name = name_str
      person.save!
      # puts "  Created Person: #{person.name}"
    end

    # Create UnitPerson
    up = UnitPerson.find_or_initialize_by(unit: unit, person: person)
    up.part = part_key
    up.status = :active
    up.save!
  end

  # 4. Parse Links
  
  # 4.1. [[Service:Account]] Format
  wiki_content.scan(/\[\[([^:]+):([^\]]+)\]\]/).each do |service, account|
    url = nil
    text = nil
    case service.downcase
    when 'twitter', 'x'
      url = "https://twitter.com/#{account}"
      text = "Twitter"
    when 'youtube channel'
      url = "https://www.youtube.com/c/#{account}"
      text = "YouTube Channel"
    end

    if url
      link = unit.links.find_or_initialize_by(url: url)
      link.text = text
      link.save!
    end
  end

  # 4.2. [Label|URL] Format
  wiki_content.scan(/\[([^|\]]+)\|([^\]]+)\]/).each do |label, url|
    next unless url.start_with?('http')
    
    link = unit.links.find_or_initialize_by(url: url)
    link.text = label
    link.save!
  end

  # 4.3. {{outlink ...}} Format
  wiki_content.scan(/\{\{outlink\s+([^\}]+)\}\}/).each do |match|
    type = match[0].strip
    url = nil
    text = nil
    
    case type
    when 'dw'
      if attributes['dw_id']
        url = "https://pc.dwango.jp/portals/artist/#{attributes['dw_id']}"
        text = "ドワンゴジェイピー"
      end
    when 'it'
      if attributes['it_id']
        url = "https://music.apple.com/jp/artist/#{attributes['it_id']}"
        text = "Apple Music"
      end
    end

    if url
      link = unit.links.find_or_initialize_by(url: url)
      link.text = text
      link.save!
    end
  end
end

puts "Done!"

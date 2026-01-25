# Usage: ID=30 PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails runner lib/tasks/import_wikipage.rb

# Define Wikipage model temporarily
class Wikipage < ActiveRecord::Base
end

wikipage_id = ENV["ID"]
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
attributes = wp.attributes.slice("dw_id", "it_id", "eplus_id")
wikipage_name = wp.name

puts "Fetched Wikipage: #{wikipage_name} (ID: #{wikipage_id}, Content size: #{wiki_content&.size})"

unless wiki_content
  puts "No valid content."
  exit
end

# Remove comment lines (lines starting with //)
wiki_content = wiki_content.lines.reject { |line| line.strip.start_with?("//") }.join

# Helper method to parse links
# Helper method to parse links
def parse_unit_links(unit, content, attributes, active: true)
  return unless content

  # 1. [[Service:Account]] Format
  content.scan(/\[\[([^:]+):([^\]]+)\]\]/).each do |service, account|
    url = nil
    text = nil
    case service.downcase
    when "twitter", "x"
      url = "https://twitter.com/#{account}"
      text = "Twitter"
    when "youtube channel"
      url = "https://www.youtube.com/c/#{account}"
      text = "YouTube Channel"
    when "spotify"
      url = "https://open.spotify.com/artist/#{account}"
      text = "Spotify"
    when "vkgy"
      url = "https://vk.gy/artists/#{account}"
      text = "vk.gy"
    when "joysound"
      url = "https://www.joysound.com/web/search/artist/#{account}"
      text = "JOYSOUND"
    when "dam"
      url = "https://www.clubdam.com/app/leaf/artistKaraokeLeaf.html?artistCode=#{account}"
      text = "DAM"
    when "カラオケdam"
      url = "https://www.clubdam.com/karaokesearch/artistleaf.html?artistCode=#{account}"
      text = "カラオケDAM"
    when "digitlink"
      url = "https://www.digitlink.jp/#{account}"
      text = "digitlink"
    when "filmarks"
      url = "https://filmarks.com/users/#{account}"
      text = "Filmarks"
    when "ototoy"
      url = "https://ototoy.jp/_/default/a/#{account}"
      text = "OTOTOY"
    when "linkfire"
      url = "https://smr.lnk.to/#{account}"
      text = "linkfire"
    when "tiktok"
      url = "https://www.tiktok.com/@#{account}"
      text = "TikTok"
    when "linktr.ee"
      url = "https://linktr.ee/#{account}"
      text = "linktr.ee"
    when "lnk.to"
      url = "https://lnk.to/#{account}"
      text = "lnk.to"
    end

    if url
      link = unit.links.find_or_initialize_by(url: url)
      link.text = text
      link.active = active
      link.save!
    end
  end

  # 2. [Label|URL] Format
  content.scan(/\[([^|\]]+)\|([^\]]+)\]/).each do |label, url|
    next unless url.start_with?("http")

    link = unit.links.find_or_initialize_by(url: url)
    link.text = label
    link.active = active
    link.save!
  end

  # 3. {{outlink ...}} Format
  content.scan(/\{\{outlink\s+([^\}]+)\}\}/).each do |match|
    type = match[0].strip
    url = nil
    text = nil

    case type
    when "dw"
      if attributes["dw_id"]
        url = "https://pc.dwango.jp/portals/artist/#{attributes['dw_id']}"
        text = "ドワンゴジェイピー"
      end
    when "it"
      if attributes["it_id"]
        url = "https://music.apple.com/jp/artist/#{attributes['it_id']}"
        text = "Apple Music"
      end
    when "tunecore"
      # Tunecore parsing might be complex, simplified here
      text = "TuneCore"
    end

    if url
      link = unit.links.find_or_initialize_by(url: url)
      link.text = text
      link.active = active
      link.save!
    end
  end
end

require "romaji"

ActiveRecord::Base.transaction do
  # ... (existing transaction start) ...
  # 2. Derive Unit Data
  # Parse unit name and kana first needed for Logic
  # 2. Derive Unit Data
  # Check first line for history definition: "OldName(Kana) → NewName(Kana)"
  first_line = wiki_content.lines.first&.strip&.gsub(/^!+/, "")&.strip
  unit_name = nil
  unit_name_kana = nil
  name_log_entries = []

  if first_line&.include?("→")
    puts "Found history definition in first line: #{first_line}"
    parsed_names = parts.map do |part|
      if part =~ /^(.+?)\s*[（\(](.+)[）\)]$/
        { name: $1.strip, name_kana: $2.strip }
      else
        { name: part, name_kana: nil }
      end
    end

    # The last one is the current name
    current_unit_data = parsed_names.last
    unit_name = current_unit_data[:name]
    unit_name_kana = current_unit_data[:name_kana]

    # Store all names in log including the current one
    name_log_entries = parsed_names
  end

  # Fallback to Wiki Title if not defined in first line
  if unit_name.nil?
    # Parse unit name and kana from Wikipage title
    # Format: "Name (Kana)" or "Name"
    if wp.title =~ /^(.+?)\s*[（\(](.+)[）\)]$/
      unit_name = $1.strip
      unit_name_kana = $2.strip
    else
      unit_name = wp.title.strip
      unit_name_kana = nil
    end
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
    # Fallback: Can't convert safely without kana. Use encoded old_key
    # Use encoded old_key (without percent signs for readability/safety)
    source_for_key = encoded_old_key.gsub(/%/, "")
  end

  unit_key = source_for_key.downcase.gsub(/\s+/, "-")

  # Important: When we look up by old_key to find existing record, we must use the ENCODED version now if we updated,
  # OR the original string if it wasn't migrated yet.
  # This is tricky. If we just changed current behavior, existing records have uncompressed 'SuG' or 'THE MADNA' or '鯨骨生物群集'.
  # We want to update them to encoded version.
  # So we should try to find by `old_key: wikipage_name` (old behavior) OR `old_key: encoded_old_key` (new behavior).

  unit = Unit.find_by(old_key: wikipage_name) || Unit.find_by(old_key: encoded_old_key) || Unit.find_or_initialize_by(key: unit_key)

  puts "Target Unit: #{unit_name} (Kana: #{unit_name_kana}, Key: #{unit_key}, Old Key: #{encoded_old_key})"

  # Check for name changes and update name_log
  if unit.persisted? && (unit.name != unit_name || unit.name_kana != unit_name_kana)
    unit.name_log ||= []
    unit.name_log << {
      name: unit.name,
      name_kana: unit.name_kana,
      date: Time.current.to_date.to_s
    }
    puts "  Name changed! Added to log: #{unit.name} (#{unit.name_kana})"
  end

  # Determine unit_type based on wiki content
  unit_type = if wiki_content.match?(/category\s+セッションバンド/i)
    :session
  else
    :band
  end

  unit.key = unit_key
  unit.name = unit_name
  unit.name_kana = unit_name_kana
  unit.name_log = name_log_entries if name_log_entries.present?
  unit.old_key = encoded_old_key # Save ENCODED string
  unit.old_wiki_text = wiki_content # Save original wiki text
  unit.unit_type = unit_type # Set unit type based on wiki content
  unit.status = :active
  unit.save!
  puts "Unit saved: #{unit.name} (id: #{unit.id}, type: #{unit_type})"

  # 3. Parse Members
  # Plugin format:
  # - Single-line: {{member part,name[,old_member_key][,sns_account]}}
  # - Multi-line:  {{member2 part,name,old_member_key,sns_account
  #                  inline history text...
  #                  more history...
  #                }}  <- closing }} must be at the beginning of a line

  # Match both single-line and multi-line plugins non-greedily
  # Find position of "!!関係者" separator
  # If found, members after this line will be marked as :left
  separator_index = wiki_content.index(/^!!関係者/) || Float::INFINITY

  # Match both single-line and multi-line plugins non-greedily
  member_regex = /\{\{member2?\s+(.*?)\}\}/m

  wiki_content.scan(member_regex) do |match|
    match_data = Regexp.last_match
    current_pos = match_data.begin(0)

    # Check if this member is after the separator
    member_status = current_pos > separator_index ? :left : :active

    content = match[0]

    # Split content into first line (arguments) and the rest (inline history)
    # Handle cases where there might not be a newline
    if content.include?("\n")
      first_line, inline_history_text = content.split("\n", 2)
    else
      first_line = content
      inline_history_text = nil
    end

    # Parse first line: part,name[,old_member_key][,sns_account]
    parts = first_line.split(",").map(&:strip)
    part_str = parts[0]
    name_str = parts[1]
    old_member_key = parts[2]
    sns_account = parts[3]

    # Clean inline_history (remove leading/trailing whitespace and newlines)
    inline_history = inline_history_text&.strip
    inline_history = nil if inline_history.blank?

    part_str = part_str.strip
    name_str = name_str.strip
    if old_member_key.present?
      old_member_key = old_member_key.strip
      if old_member_key =~ /^\(/ && old_member_key =~ /\)$/
        old_member_key = [ name_str, old_member_key ].join
      end
    else
      old_member_key = name_str
    end

    old_member_key = URI.encode_www_form_component(old_member_key.encode("EUC-JP"))

    # Map Part
    part_key = case part_str.downcase
    when "vocal" then :vocal
    when "guitar" then :guitar
    when "bass" then :bass
    when "drums" then :drums
    when "keyboard" then :keyboard
    when "dj" then :dj
    else :unknown
    end

    # Create Person
    # Use unit_key prefix for uniqueness
    # Convert name to romaji for URL-safe key
    person_name_for_key = if name_str.match?(/^[[:ascii:]\s-]+$/)
      # Already ASCII
      name_str
    else
      # Try to convert to romaji
      romaji_attempt = Romaji.kana2romaji(name_str)
      # If romanization failed (still contains non-ASCII), use old_member_key
      if romaji_attempt.match?(/[^[:ascii:]]/)
        # Use the already-encoded old_member_key (without unit prefix)
        old_member_key.gsub(/\%/, "")
      else
        romaji_attempt
      end
    end
    person_key = "#{unit_key}_#{person_name_for_key.downcase.gsub(/\s+/, '-')}"
    person = Person.find_by(key: person_key)

    # Create UnitPerson
    up = if person.present?
           UnitPerson.find_or_initialize_by(unit: unit, person: person)
    else
      UnitPerson.find_or_initialize_by(unit: unit, person_name: name_str)
    end
    up.person_id = person.id if person.present?
    up.person_key = person_key unless person.present? # Set person_key when person doesn't exist
    up.part = part_key
    up.status = member_status
    up.old_person_key = old_member_key
    up.inline_history = inline_history # Save inline history text
    up.sns = [ sns_account.strip ] if sns_account.present?
    up.save!
  end

  # 4. Parse Links

  # 4. Parse Links

  # 4.1. Unlink Plugin (Inactive Links)
  # Format: {{unlink ... }} (multi-line supported)
  # Match content non-greedily until the closing }}
  unlink_regex = /\{\{unlink\s+(.*?)\}\}/m

  puts "Scanning for unlink blocks..."
  wiki_content.scan(unlink_regex).each do |match|
    puts "Found unlink block!"
    unlink_content = match[0]
    parse_unit_links(unit, unlink_content, attributes, active: false)
  end

  # 4.2. Active Links (Remove unlink blocks first)
  active_content = wiki_content.gsub(unlink_regex, "")
  puts "Parsing active links..."
  parse_unit_links(unit, active_content, attributes, active: true)
end

puts "Done!"

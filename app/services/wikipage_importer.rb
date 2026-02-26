# frozen_string_literal: true

require 'romaji'

# rubocop:disable Metrics/ClassLength, Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
class WikipageImporter < BaseWikipageImporter
  def self.import(wikipage)
    new(wikipage).import
  end

  def self.valid_unit?(wikipage)
    return false if ignored?(wikipage)
    return false if wikipage.wiki.blank?

    # Check for member section or specific category that indicates a unit
    # Simple check: has {{member...}} tag or !Part... line
    has_member_plugin = wikipage.wiki.match?(/\{\{member2?\s+.*?\}\}/m)
    # Support both formats: !Part… [[Name]] and ![[Name]]… Part
    has_old_member_format = wikipage.wiki.match?(/^!([^…]+)…\s*\[\[/) || wikipage.wiki.match?(/^!\[\[.+?\]\]\s*…/)

    has_member_plugin || has_old_member_format
  end

  protected

  # Override to preserve {{member...}} blocks during preprocessing
  def preprocess_content
    # Remove b_hidden blocks first
    @wiki_content.gsub!(/\{\{b_hidden.*?(?:^\}\}|\z)/m, '')

    # Extract and preserve {{member...}} blocks before removing comments
    @member_blocks = []
    @wiki_content.gsub!(/\{\{member2?\s+.*?\}\}/m) do |block|
      placeholder = "__MEMBER_BLOCK_#{@member_blocks.length}__"
      @member_blocks << block
      placeholder
    end

    # Remove comment lines (but not from member blocks)
    @wiki_content = @wiki_content.lines.reject { |line| line.strip.start_with?('//') }.join

    # Restore member blocks
    @member_blocks.each_with_index do |block, index|
      @wiki_content.gsub!("__MEMBER_BLOCK_#{index}__", block)
    end
  end

  def process_import
    import_unit
  end

  private

  def parse_unit_names_from_first_line(first_line)
    if first_line&.include?('→')
      parse_unit_names_from_arrow_line(first_line)
    else
      parse_unit_names_from_plain_line(first_line)
    end
  end

  def parse_unit_names_from_arrow_line(first_line)
    arrow_parts = first_line.split('→').map(&:strip)
    last_pieces = arrow_parts.last.to_s.split('、').map(&:strip)
    aliases = parse_alias_parts(last_pieces[1..])
    arrow_parts[-1] = last_pieces.first.to_s if last_pieces.size > 1

    parsed_names = arrow_parts.map { |part| parse_name_part(part) }
    current = parsed_names.last
    { name: current[:name], name_kana: current[:name_kana], name_log: parsed_names, aliases: }
  end

  def parse_unit_names_from_plain_line(first_line)
    pieces = first_line.to_s.split('、').map(&:strip)
    aliases = parse_alias_parts(pieces[1..])
    main_part = pieces.first.to_s
    name, name_kana = extract_name_and_kana_from_part(main_part)
    { name:, name_kana:, name_log: [], aliases: }
  end

  def parse_unit_names_from_title
    title = @wikipage.title.to_s.strip
    pieces = title.split('、').map(&:strip)
    main_title = pieces.first.to_s
    if main_title =~ /^(.+?)\s*[（(](.+)[）)]$/
      { name: Regexp.last_match(1).strip, name_kana: Regexp.last_match(2).strip, alias_parts: pieces[1..] }
    else
      { name: main_title, name_kana: nil, alias_parts: pieces[1..] }
    end
  end

  def parse_name_part(part)
    if part =~ /\{\{rb\s+(.+?),\s*(.+?)\}\}/
      { name: extract_name_from_wiki_link(Regexp.last_match(1).strip), name_kana: Regexp.last_match(2).strip }
    elsif part =~ /^(.+?)\s*[（(](.+)[）)]$/
      { name: extract_name_from_wiki_link(Regexp.last_match(1).strip), name_kana: Regexp.last_match(2).strip }
    else
      { name: extract_name_from_wiki_link(part), name_kana: nil }
    end
  end

  def extract_name_and_kana_from_part(part)
    if part =~ /^\s*\{\{rb\s+(.+?),\s*(.+?)\}\}(.*)$/
      name = extract_name_from_wiki_link(Regexp.last_match(1).strip) + Regexp.last_match(3)
      [name, Regexp.last_match(2).strip]
    elsif part =~ /^(.+?)\s*[（(](.+)[）)]$/
      [extract_name_from_wiki_link(Regexp.last_match(1).strip), Regexp.last_match(2).strip]
    else
      [nil, nil]
    end
  end

  def import_unit
    # 2. Derive Unit Data
    # Check first line for history definition: "OldName(Kana) → NewName(Kana)"
    first_line = @wiki_content.lines.first&.strip&.gsub(/^!+/, '')&.strip
    parsed = parse_unit_names_from_first_line(first_line)
    unit_name      = parsed[:name]
    unit_name_kana = parsed[:name_kana]
    name_log_entries = parsed[:name_log]
    unit_aliases     = parsed[:aliases]

    # Fallback to Wiki Title
    if unit_name.nil?
      parsed = parse_unit_names_from_title
      unit_aliases = parse_alias_parts(parsed[:alias_parts]) if unit_aliases.empty?
      unit_name      = parsed[:name]
      unit_name_kana = parsed[:name_kana]
    end

    if unit_name.blank?
      puts "Skipping Wikipage #{@wikipage.id}: No unit name found"
      return
    end

    encoded_old_key = URI.encode_www_form_component(@wikipage_name.encode('EUC-JP'))

    source_for_key = if @wikipage_name.match?(/^[[:ascii:]\s-]+$/)
                       @wikipage_name
                     elsif unit_name.match?(/\A[a-zA-Z0-9\s]+\z/)
                       unit_name
                     elsif unit_name_kana.present?
                       Romaji.kana2romaji(unit_name_kana)
                     else
                       encoded_old_key.gsub(/%/, '')
                     end

    # Replace any non-alphanumeric character (except -) with -
    unit_key = source_for_key.downcase.gsub(/[^a-z0-9-]+/, '-').gsub(/-+/, '-')

    # Find existing unit by old_key only
    # If not found, create a new unit (collision will be resolved later)
    unit = Unit.find_by(old_key: @wikipage_name) || Unit.find_by(old_key: encoded_old_key)
    unit = Unit.new if unit.nil?

    # Check for name changes and update name_log
    if unit.persisted? && (unit.name != unit_name || unit.name_kana != unit_name_kana)
      unit.name_log ||= []
      unit.name_log << {
        name: unit.name,
        name_kana: unit.name_kana
      }
    end

    unit_type = if @wiki_content.match?(/category\s+セッションバンド/i)
                  :session
                else
                  :band
                end

    unique_key = resolve_key_collision(unit_key, unit.id)
    unit.key = unique_key
    unit.name = unit_name
    unit.name_kana = unit_name_kana
    unit.name_log = name_log_entries if name_log_entries.present?
    unit[:aliases] = unit_aliases if unit_aliases.any?
    unit.old_key = encoded_old_key
    unit.old_wiki_id = @wikipage.id
    unit.old_wiki_text = @original_content
    unit.unit_type = unit_type
    unit.status = :active
    unit.save!

    parse_categories(unit)
    parse_members(unit)
    parse_footer_links(unit)
    parse_youtube_tags(unit)
    parse_band_name_history(unit, unit_name, unit_name_kana)
    parse_sections(unit)
    parse_activity_period(unit)
  end

  def parse_band_name_history(unit, current_name, current_kana) # rubocop:disable Metrics/PerceivedComplexity
    return if unit.name_log.present? && unit.name_log.size > 1

    history_section = @wiki_content.match(/^!!バンド名の?変遷.*?\n(.+?)(?=\n!!|\z)/m)&.[](1)
    return unless history_section

    entries = []

    # Arrow format: → [[Name]] → [[Name]]{{fn Date}}
    if history_section.include?('→')
      parts = history_section.split('→').map(&:strip).reject(&:blank?)
      parts.each_with_index do |part, idx|
        # Extract date first from {{fn ...}}
        date_match = part.match(/\{\{fn\s+(.*?)\}\}/)
        date = date_match ? date_match[1] : nil

        # Remove {{fn ...}} tag before extracting name to avoid it being part of the name if extraction fails or works unexpectedly
        clean_part = part.gsub(/\{\{fn\s+.*?\}\}/, '').strip
        name = extract_name_from_wiki_link(clean_part).strip

        entries << { name: name, name_kana: nil, date: date, index: idx + 1 }
      end
    else
      # Line format: Date...Name
      current_index = 1
      history_section.lines.each do |line|
        line = line.strip
        next if line.blank?

        next unless line =~ /^(.+?)…(.+)$/

        date = Regexp.last_match(1).strip
        name = Regexp.last_match(2).strip
        entries << { name: name, name_kana: nil, date: date, index: current_index }
        current_index += 1
      end
    end

    return if entries.empty?

    # If the last entry matches the current unit name, update its kana
    entries.last[:name_kana] = current_kana if entries.last[:name] == current_name

    unit.name_log = entries
    unit.save!
  end

  def parse_categories(unit)
    category_regex = /\{\{category\s+(.*?)\}\}/i
    categories = []
    @wiki_content.scan(category_regex) do |match|
      content = match[0]
      content.split(',').each do |cat|
        categories << cat.strip
      end
    end

    return unless categories.any?

    unit.tag_index_items.destroy_all

    categories.each do |cat_raw|
      index_name = cat_raw.strip
      tag_index = TagIndex.find_or_create_by(name: index_name)
      TagIndexItem.create!(
        tag_index: tag_index,
        indexable: unit
      )
    end
  end

  def extract_member_blocks
    results = []
    pos = 0

    while (start_pos = @wiki_content.index(/\{\{member2?\s+/, pos))
      # Find the matching closing }}
      bracket_count = 0
      i = start_pos
      content_start = nil

      while i < @wiki_content.length
        if @wiki_content[i, 2] == '{{'
          bracket_count += 1
          content_start = i + 2 if bracket_count == 1 && @wiki_content[i..] =~ /^\{\{member2?\s+/
          i += 2
        elsif @wiki_content[i, 2] == '}}'
          bracket_count -= 1
          if bracket_count.zero?
            # Found the matching closing bracket
            content = @wiki_content[content_start...i].sub(/^member2?\s+/, '')
            results << {
              content: content,
              begin: start_pos,
              end: i + 2
            }
            pos = i + 2
            break
          end
          i += 2
        else
          i += 1
        end
      end

      break if bracket_count != 0 # Unmatched brackets, stop
    end

    results
  end

  def member_section_ranges
    ranges = []
    @wiki_content.scan(/^!!(.*?)(?:\n|$)/) do
      section_name = Regexp.last_match(1).strip
      next unless section_name.match?(/^(メンバー|関係者)/)

      section_start = Regexp.last_match.begin(0)
      header_end = Regexp.last_match.end(0)
      next_section = @wiki_content.index(/^!!/, header_end)
      section_end = next_section || @wiki_content.length
      ranges << (section_start...section_end)
    end
    ranges
  end

  def in_member_section?(pos, ranges)
    ranges.any? { |r| r.cover?(pos) }
  end

  def parse_members(unit)
    separator_index = @wiki_content.index(/^!!関係者/) || Float::INFINITY
    valid_ranges = member_section_ranges
    restrict_to_sections = valid_ranges.any?
    current_order = 1

    # Plugin format - use balanced bracket matching
    extract_member_blocks.each do |block_data|
      current_pos = block_data[:begin]
      next if restrict_to_sections && !in_member_section?(current_pos, valid_ranges)

      member_status = current_pos > separator_index ? :left : :active
      content = block_data[:content]

      if content.include?("\n")
        first_line, inline_history_text = content.split("\n", 2)
      else
        first_line = content
        inline_history_text = nil
      end

      parts = first_line.split(',').map(&:strip)
      part_str = parts[0]
      name_str = parts[1]
      old_member_key = parts[2]
      sns_account = parts[3]

      inline_history = inline_history_text&.strip
      inline_history = nil if inline_history.blank?

      part_str = part_str&.strip
      name_str = name_str&.strip

      next if name_str.blank?

      if old_member_key.present? && old_member_key != '-'
        old_member_key = old_member_key.strip
        old_member_key = [name_str, old_member_key].join if old_member_key =~ /^\(/ && old_member_key =~ /\)$/
      else
        old_member_key = name_str
      end

      old_member_key = URI.encode_www_form_component(old_member_key.encode('EUC-JP'))

      register_member(unit, part_str, name_str, old_member_key, sns_account, inline_history, member_status, current_order)
      current_order += 1
    end

    # Old Member Format
    # Current supported formats:
    # 1. !Part… [[Name]]
    # 2. ![[Name]]… Part
    # 3. !Part… PlainName (no wiki link)
    old_member_regex1 = /^!([^…\n]+)…\s*\[\[([^|\]]+)(?:\|([^\]]+))?\]\]/
    old_member_regex2 = /^!\[\[([^|\]\n]+)(?:\|([^\]\n]+))?\]\]\s*…\s*([^…\n\r]+)/
    old_member_regex3 = /^!([^…\n]+)…[^\S\n]*([^\[\s\n][^\n]*)/

    @wiki_content.scan(old_member_regex1) do |match|
      match_data = Regexp.last_match
      current_pos = match_data.begin(0)
      next if restrict_to_sections && !in_member_section?(current_pos, valid_ranges)

      member_status = current_pos > separator_index ? :left : :active

      part_str = match[0].strip
      name_str = match[1].strip
      old_member_key = match[2]&.strip

      register_old_format_member(unit, part_str, name_str, old_member_key, member_status, current_order)
      current_order += 1
    end

    @wiki_content.scan(old_member_regex2) do |match|
      match_data = Regexp.last_match
      current_pos = match_data.begin(0)
      next if restrict_to_sections && !in_member_section?(current_pos, valid_ranges)

      member_status = current_pos > separator_index ? :left : :active

      name_str = match[0].strip
      old_member_key = match[1]&.strip
      part_str = match[2].strip

      register_old_format_member(unit, part_str, name_str, old_member_key, member_status, current_order)
      current_order += 1
    end

    @wiki_content.scan(old_member_regex3) do |match|
      match_data = Regexp.last_match
      current_pos = match_data.begin(0)
      next if restrict_to_sections && !in_member_section?(current_pos, valid_ranges)

      member_status = current_pos > separator_index ? :left : :active

      part_str = match[0].strip
      name_str = match[1].strip
      next if name_str.empty?

      register_old_format_member(unit, part_str, name_str, nil, member_status, current_order)
      current_order += 1
    end
  end

  # rubocop:disable Metrics/ParameterLists
  def register_old_format_member(unit, part_str, name_str, old_member_key, member_status, order_in_period)
    # rubocop:enable Metrics/ParameterLists
    if old_member_key.present?
      old_member_key = old_member_key.strip
      old_member_key = [name_str, old_member_key].join if old_member_key =~ /^\(/ && old_member_key =~ /\)$/
    else
      old_member_key = name_str
    end

    old_member_key = URI.encode_www_form_component(old_member_key.encode('EUC-JP'))

    register_member(unit, part_str, name_str, old_member_key, nil, nil, member_status, order_in_period)
  end

  # rubocop:disable Metrics/ParameterLists
  def register_member(unit, part_str, name_str, old_member_key, sns_account, inline_history, member_status, order_in_period)
    # rubocop:enable Metrics/ParameterLists
    # Clean up part string: remove leading '!'
    cleaned_part_str = part_str.to_s.sub(/^!/, '')

    # Check for support keywords FIRST (before wiki Parsing eats it if it works on generic text)
    # Actually, the example is !Support [[Key|Keyboard]].
    # cleaned_part_str matches /support/i.
    is_support = cleaned_part_str.match?(/support|サポート/i)
    # Remove support keyword from the full string
    cleaned_part_str = cleaned_part_str.gsub(/support|サポート/i, '').strip

    # Check for wiki alias syntax [[Alias|Part]]
    part_alias_from_wiki = nil
    if (match = cleaned_part_str.match(/\[\[(.*?)\|(.*?)\]\]/))
      part_alias_from_wiki = match[1].strip
      cleaned_part_str = match[2].strip
    end

    part_key = case cleaned_part_str.downcase
               when 'vocal' then :vocal
               when 'guitar' then :guitar
               when 'bass' then :bass
               when 'drums' then :drums
               when 'keyboard' then :keyboard
               when 'dj' then :dj
               else
                 puts "[UNKNOWN_PART] '#{cleaned_part_str}' in Unit: #{unit.name} (WikiID: #{@wikipage.id})" unless cleaned_part_str.blank?
                 :unknown
               end

    part_alias = part_alias_from_wiki.presence || (part_key == :unknown && cleaned_part_str.present? ? cleaned_part_str : nil)

    person_name_for_key = if name_str.match?(/^[[:ascii:]\s-]+$/)
                            name_str
                          else
                            romaji_attempt = Romaji.kana2romaji(name_str)
                            if romaji_attempt.match?(/[^[:ascii:]]/)
                              old_member_key.gsub(/%/, '')
                            else
                              romaji_attempt
                            end
                          end

    unit_key = unit.key
    person_key = "#{unit_key}_#{person_name_for_key.downcase.gsub(/\s+/, '-')}"

    person = Person.find_by(key: person_key)

    if person.present? && (person.name != name_str)
      person.name_log ||= []
      person.name_log << {
        name: person.name,
        name_kana: person.name_kana
      }
    end

    up = if person.present?
           UnitPerson.find_or_initialize_by(unit: unit, person: person)
         else
           UnitPerson.find_or_initialize_by(unit: unit, person_name: name_str)
         end
    up.person_id = person.id if person.present?
    up.person_key = person_key unless person.present?
    up.part = part_key
    up.status = member_status
    up.support = is_support
    up.part_alias = part_alias if part_alias
    up.old_person_key = old_member_key
    up.inline_history = inline_history
    up.sns = [sns_account.strip] if sns_account.present?
    up.order_in_period = order_in_period
    up.save!

    return unless person.present?

    person.name = name_str
    person.save!
  end

  def parse_footer_links(unit)
    link_section_content = if @wiki_content =~ /!!リンク\s*\n(.+?)(?=\n!!|\z)/m
                             Regexp.last_match(1).strip
                           else
                             ''
                           end

    return unless link_section_content.present?

    unlink_regex = /\{\{unlink\s+(.*?)\}\}/m
    link_section_content.scan(unlink_regex).each do |match|
      unlink_content = match[0]
      parse_wiki_links(unit, unlink_content, false)
    end

    active_content = link_section_content.gsub(unlink_regex, '')
    parse_wiki_links(unit, active_content, true)
  end

  def parse_activity_period(unit)
    regex = /^\*活動時期\s*(?:…|\.\.\.)\s*(.+)/
    entries = []

    @wiki_content.scan(regex) do |match|
      value = match[0].strip
      from, to = value.split(/\s*~\s*/, 2)
      entries << { 'from' => extract_date_only(from), 'to' => extract_date_only(to) }
    end

    unit.update!(activity_period: entries) if entries.present?
  end

  def extract_date_only(value)
    return nil if value.nil?

    value.gsub(/\(.*?\)/, '').gsub(/（.*?）/, '').strip.presence
  end

  def resolve_key_collision(base_key, current_id = nil)
    return base_key unless Unit.where(key: base_key).where.not(id: current_id).exists?

    suffix = 2
    loop do
      candidate = "#{base_key}-#{suffix}"
      return candidate unless Unit.where(key: candidate).where.not(id: current_id).exists?

      suffix += 1
    end
  end
  # rubocop:enable Metrics/ClassLength, Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
end

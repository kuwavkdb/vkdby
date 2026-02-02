# frozen_string_literal: true

require 'romaji'

# rubocop:disable Metrics/ClassLength, Metrics/AbcSize, Metrics/PerceivedComplexity
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
    has_old_member_format = wikipage.wiki.match?(/^!([^…]+)…\s*\[\[/) || wikipage.wiki.match?(/^!\[\[.+?\]\]…/)

    has_member_plugin || has_old_member_format
  end

  protected

  # Override to preserve {{member...}} blocks during preprocessing
  def preprocess_content
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

  def import_unit
    # 2. Derive Unit Data
    # Check first line for history definition: "OldName(Kana) → NewName(Kana)"
    first_line = @wiki_content.lines.first&.strip&.gsub(/^!+/, '')&.strip
    unit_name = nil
    unit_name_kana = nil
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

      current_unit_data = parsed_names.last
      unit_name = current_unit_data[:name]
      unit_name_kana = current_unit_data[:name_kana]
      name_log_entries = parsed_names
    elsif first_line =~ /^(.+?)\s*[（(](.+)[）)]$/
      raw_name = Regexp.last_match(1).strip
      unit_name = extract_name_from_wiki_link(raw_name)
      unit_name_kana = Regexp.last_match(2).strip
    end

    # Fallback to Wiki Title
    if unit_name.nil?
      title = @wikipage.title.to_s.strip
      if title =~ /^(.+?)\s*[（(](.+)[）)]$/
        unit_name = Regexp.last_match(1).strip
        unit_name_kana = Regexp.last_match(2).strip
      else
        unit_name = title
        unit_name_kana = nil
      end
    end

    if unit_name.blank?
      puts "Skipping Wikipage #{@wikipage.id}: No unit name found"
      return
    end

    encoded_old_key = URI.encode_www_form_component(@wikipage_name.encode('EUC-JP'))

    source_for_key = if @wikipage_name.match?(/^[[:ascii:]\s-]+$/)
                       @wikipage_name
                     elsif unit_name_kana.present?
                       Romaji.kana2romaji(unit_name_kana)
                     else
                       encoded_old_key.gsub(/%/, '')
                     end

    # Replace any non-alphanumeric character (except -) with -
    unit_key = source_for_key.downcase.gsub(/[^a-z0-9-]+/, '-').gsub(/-+/, '-')

    unit = Unit.find_by(old_key: @wikipage_name) || Unit.find_by(old_key: encoded_old_key) || Unit.find_or_initialize_by(key: unit_key)

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
    unit.old_key = encoded_old_key
    unit.old_wiki_id = @wikipage.id
    unit.old_wiki_text = @wiki_content
    unit.unit_type = unit_type
    unit.status = :active
    unit.save!

    parse_categories(unit)
    parse_members(unit)
    parse_footer_links(unit)
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

  def parse_members(unit)
    separator_index = @wiki_content.index(/^!!関係者/) || Float::INFINITY
    current_order = 1

    # Plugin format - use balanced bracket matching
    extract_member_blocks.each do |block_data|
      current_pos = block_data[:begin]
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

      if old_member_key.present?
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
    old_member_regex1 = /^!([^…\n]+)…\s*\[\[([^|\]]+)(?:\|([^\]]+))?\]\]/
    old_member_regex2 = /^!\[\[([^|\]\n]+)(?:\|([^\]\n]+))?\]\]…([^…\n]+)/

    @wiki_content.scan(old_member_regex1) do |match|
      match_data = Regexp.last_match
      current_pos = match_data.begin(0)
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
      member_status = current_pos > separator_index ? :left : :active

      name_str = match[0].strip
      old_member_key = match[1]&.strip
      part_str = match[2].strip

      register_old_format_member(unit, part_str, name_str, old_member_key, member_status, current_order)
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

  def resolve_key_collision(base_key, current_id = nil)
    return base_key unless Unit.where(key: base_key).where.not(id: current_id).exists?

    suffix = 2
    loop do
      candidate = "#{base_key}-#{suffix}"
      return candidate unless Unit.where(key: candidate).where.not(id: current_id).exists?

      suffix += 1
    end
  end
  # rubocop:enable Metrics/ClassLength, Metrics/AbcSize, Metrics/PerceivedComplexity
end

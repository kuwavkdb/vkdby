# frozen_string_literal: true

require 'romaji'

# 旧サイトの wikipages（{{category ライブハウス・ホール}}）から Venue を取り込む（issue #1688）。
# 名前・改名履歴・別名の抽出は WikipageImporter（Unit）と同じ記法だが、
# Venue は見出しに `!!!` が付く点や住所・キャパシティなど項目が異なるため、
# 共通化はせず同様のロジックをこちらに実装している。
# rubocop:disable Metrics/ClassLength, Metrics/AbcSize, Metrics/PerceivedComplexity
class VenueImporter < BaseWikipageImporter
  def self.import(wikipage)
    new(wikipage).import
  end

  def self.valid_venue?(wikipage)
    return false if ignored?(wikipage)
    return false if wikipage.wiki.blank?

    wikipage.wiki.match?(/\{\{category\s+ライブハウス・ホール\}\}/)
  end

  protected

  def process_import
    import_venue
  end

  private

  def parse_venue_names_from_first_line(first_line)
    stripped_for_check = first_line.to_s.gsub(/\[\[[^\]]*\]\]/, '')
    if stripped_for_check.include?('→')
      parse_venue_names_from_arrow_line(first_line)
    elsif (m = first_line.to_s.match(/\[\[([^|\]]*→[^|\]]*)\|[^\]]*\]\](.*)/))
      parse_venue_names_from_arrow_line(m[1].strip + m[2])
    else
      parse_venue_names_from_plain_line(first_line)
    end
  end

  def parse_venue_names_from_arrow_line(first_line)
    arrow_parts = first_line.split('→').map(&:strip)
    last_pieces = arrow_parts.last.to_s.split('、').map(&:strip)
    aliases = parse_alias_parts(last_pieces[1..])
    arrow_parts[-1] = last_pieces.first.to_s if last_pieces.size > 1

    parsed_names = arrow_parts.map { |part| parse_venue_name_part(part) }
    current = parsed_names.last
    { name: current[:name], name_kana: current[:name_kana], name_log: parsed_names, aliases: }
  end

  def parse_venue_names_from_plain_line(first_line)
    pieces = first_line.to_s.split('、').map(&:strip)
    aliases = parse_alias_parts(pieces[1..])
    main_part = pieces.first.to_s
    name, name_kana = extract_venue_name_and_kana_from_part(main_part)
    { name:, name_kana:, name_log: [], aliases: }
  end

  def parse_venue_names_from_title
    title = @wikipage.title.to_s.strip
    pieces = title.split('、').map(&:strip)
    main_title = pieces.first.to_s
    if main_title =~ /^(.+?)\s*[（(](.+)[）)]$/
      { name: Regexp.last_match(1).strip, name_kana: Regexp.last_match(2).strip, alias_parts: pieces[1..] }
    else
      { name: main_title, name_kana: nil, alias_parts: pieces[1..] }
    end
  end

  def parse_venue_name_part(part)
    stripped = extract_name_from_wiki_link(part.to_s)
    if stripped =~ /\{\{rb\s+(.+?),\s*(.+?)\}\}/
      { name: Regexp.last_match(1).strip, name_kana: Regexp.last_match(2).strip }
    elsif stripped =~ /^(.*\S)\s*[（(]([^（(）)]+)[）)]\s*$/
      { name: Regexp.last_match(1).strip, name_kana: Regexp.last_match(2).strip }
    else
      { name: stripped, name_kana: nil }
    end
  end

  def extract_venue_name_and_kana_from_part(part)
    stripped = extract_name_from_wiki_link(part.to_s)
    if stripped =~ /^\s*\{\{rb\s+(.+?),\s*(.+?)\}\}(.*)$/
      name = Regexp.last_match(1).strip + Regexp.last_match(3)
      [name, Regexp.last_match(2).strip]
    elsif stripped =~ /^(.*\S)\s*[（(]([^（(）)]+)[）)]\s*$/
      [Regexp.last_match(1).strip, Regexp.last_match(2).strip]
    else
      [stripped.presence, nil]
    end
  end

  def import_venue
    heading_line = @wiki_content.lines.find { |l| l.strip.start_with?('!') }
    first_line = heading_line&.strip&.gsub(/^!+/, '')&.strip
    # 読みが空の「名称（）」表記はかな抽出に失敗するため、空括弧のみ先に除去する
    first_line = first_line&.gsub(/[（(]\s*[）)]/, '')
    parsed = parse_venue_names_from_first_line(first_line)
    venue_name      = parsed[:name]
    venue_name_kana = parsed[:name_kana]
    name_log_entries = parsed[:name_log]
    venue_aliases = parsed[:aliases]

    if venue_name.nil?
      parsed = parse_venue_names_from_title
      venue_aliases = parse_alias_parts(parsed[:alias_parts]) if venue_aliases.empty?
      venue_name      = parsed[:name]
      venue_name_kana = parsed[:name_kana]
    end

    return if venue_name.blank?

    encoded_old_key = URI.encode_www_form_component(@wikipage_name.encode('EUC-JP'))

    source_for_key = if @wikipage_name.match?(/^[[:ascii:]\s-]+$/)
                       @wikipage_name
                     elsif venue_name.match?(/\A[a-zA-Z0-9\s]+\z/)
                       venue_name
                     elsif venue_name_kana.present?
                       Romaji.kana2romaji(venue_name_kana)
                     else
                       encoded_old_key.gsub(/%/, '')
                     end

    venue_key = source_for_key.downcase.gsub(/[^a-z0-9-]+/, '-').gsub(/-+/, '-')

    venue = Venue.find_by(old_key: @wikipage_name) || Venue.find_by(old_key: encoded_old_key)
    venue = Venue.new if venue.nil?

    if venue.persisted? && (venue.name != venue_name || venue.name_kana != venue_name_kana)
      venue.name_log ||= []
      venue.name_log << {
        'name' => venue.name,
        'name_kana' => venue.name_kana
      }
    end

    unique_key = resolve_key_collision(venue_key, venue.id)
    venue.key = unique_key
    venue.name = venue_name
    venue.name_kana = venue_name_kana
    venue.name_log = name_log_entries.map(&:stringify_keys) if name_log_entries.present?
    venue[:aliases] = venue_aliases
    venue.old_key = encoded_old_key
    venue.old_wiki_id = @wikipage.id
    venue.old_wiki_text = @original_content
    venue.venue_type = :live_house
    venue.status = :active
    venue.prefecture = extract_prefecture
    venue.address = extract_address
    venue.capacity = extract_capacity
    venue.save!

    parse_footer_links(venue)

    venue
  end

  def address_section_content
    return @address_section_content if defined?(@address_section_content)

    @address_section_content = (Regexp.last_match(1).strip if @wiki_content =~ /^!!?住所\n((?:(?!^!).*\n)*)/)
  end

  def extract_address
    content = address_section_content
    return nil if content.blank?

    first_line = content.lines.first.to_s.strip.gsub(/^\*+\s*/, '')
    first_line = extract_name_from_wiki_link(first_line)
    first_line.presence
  end

  def extract_prefecture
    content = address_section_content
    return nil if content.blank?

    Venue::PREFECTURES.find { |pref| content.include?(pref) }
  end

  def extract_capacity
    return nil unless @wiki_content =~ /^!!キャパシティ\n((?:(?!^!).*\n)*)/

    section = Regexp.last_match(1).strip
    match = section.match(/(\d[\d,]*)/)
    return nil unless match

    match[1].delete(',').to_i.presence
  end

  def parse_footer_links(venue)
    link_section_content = if @wiki_content =~ /!!リンク\s*\n(.+?)(?=\n!!|\z)/m
                             Regexp.last_match(1).strip
                           else
                             ''
                           end

    return unless link_section_content.present?

    unlink_regex = /\{\{unlink\s+(.*?)\}\}/m
    link_section_content.scan(unlink_regex).each do |match|
      unlink_content = match[0]
      parse_wiki_links(venue, unlink_content, false)
    end

    active_content = link_section_content.gsub(unlink_regex, '')
    parse_wiki_links(venue, active_content, true)
  end

  def resolve_key_collision(base_key, current_id = nil)
    return base_key unless Venue.where(key: base_key).where.not(id: current_id).exists?

    suffix = 2
    loop do
      candidate = "#{base_key}-#{suffix}"
      return candidate unless Venue.where(key: candidate).where.not(id: current_id).exists?

      suffix += 1
    end
  end
  # rubocop:enable Metrics/ClassLength, Metrics/AbcSize, Metrics/PerceivedComplexity
end

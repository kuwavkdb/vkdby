# frozen_string_literal: true

# WikipageImporterV2
# Extends WikipageImporter to parse dated member sections and create UnitSnapshot records
# Supports formats like:
# - !!メンバー（yyyy/mm/dd）
# - !!メンバー（yyyy年mm月dd日）
# - !!メンバー（結成時）
# rubocop:disable Metrics/ClassLength
class WikipageImporterV2 < WikipageImporter
  def self.import(wikipage)
    new(wikipage).import
  end

  protected

  def process_import
    # まず通常のユニットインポートを実行
    super

    # 次にスナップショットを生成
    import_snapshots
  end

  private

  def import_snapshots
    unit = Unit.find_by(old_wiki_id: @wikipage.id)
    return unless unit

    # 既存のスナップショットを削除し、再作成する
    unit.unit_snapshots.destroy_all

    # 日付付きメンバーセクションを抽出
    dated_sections = extract_dated_member_sections

    dated_sections.each_with_index do |section_data, index|
      create_snapshot(unit, section_data, index)
    end
  end

  # 日付付きメンバーセクションを抽出
  # 例: !!メンバー（2023/04/15）、!!メンバー（2023年4月15日）、!!メンバー（結成時）
  def extract_dated_member_sections
    return [] unless @original_content

    sections = []

    extract_pattern1(sections)
    extract_pattern2(sections)
    extract_year_only_patterns(sections)
    extract_pattern5(sections)

    sort_sections(sections)
  end

  def sort_sections(sections)
    sections.sort_by { |s| s[:date] || Date.new(1900, 1, 1) } # 日付順にソート（日付なしは先頭）
  end

  def extract_pattern1(sections)
    # パターン1: !!メンバー（yyyy/mm/dd）
    @original_content.scan(%r{^!!メンバーー?(?:（|\()([0-9]{4})/([0-9]{1,2})/([0-9]{1,2})(?:）|\))}m) do
      match_data = Regexp.last_match
      year = match_data[1].to_i
      month = match_data[2].to_i
      day = match_data[3].to_i

      # 年が 0 の場合はサンプルテンプレートなのでスキップ
      next if year.zero?

      # セクションの内容を抽出（次の !! まで）
      start_pos = match_data.end(0)
      content = extract_section_content(start_pos)

      add_section(sections, date_parts: { year: year, month: month, day: day }, content: content, position: match_data.begin(0))
    end
  end

  def extract_pattern2(sections)
    # パターン2: !!メンバー（yyyy年mm月dd日）
    @original_content.scan(/^!!メンバーー?(?:（|\()([0-9]{4})年([0-9]{1,2})月([0-9]{1,2})日(?:）|\))/m) do
      match_data = Regexp.last_match
      year = match_data[1].to_i
      month = match_data[2].to_i
      day = match_data[3].to_i

      # 年が 0 の場合はサンプルテンプレートなのでスキップ
      next if year.zero?

      # セクションの内容を抽出（次の !! まで）
      start_pos = match_data.end(0)
      content = extract_section_content(start_pos)

      add_section(sections, date_parts: { year: year, month: month, day: day }, content: content, position: match_data.begin(0))
    end
  end

  def extract_year_only_patterns(sections)
    # パターン3: !!メンバー（yyyy） または !!メンバー（yyyy年）
    @original_content.scan(/^!!メンバーー?(?:（|\()([0-9]{4})(?:年)?(?:）|\))/m) do
      match_data = Regexp.last_match
      year = match_data[1].to_i

      start_pos = match_data.end(0)
      content = extract_section_content(start_pos)

      # 年のみの場合は日付不定のためnil、ラベルで年を保持
      sections << {
        date: nil,
        label: "#{year}年",
        content: content,
        position: match_data.begin(0)
      }
    end
  end

  def extract_pattern5(sections)
    extract_named_pattern(sections, '結成時', '結成時')
    extract_named_pattern(sections, '現在', nil, current: true)

    # パターン4: !!メンバー（その他文字列）
    # 日付形式でないものをすべて抽出
    @original_content.scan(/^!!メンバーー?(?:（|\()(.+?)(?:）|\))/m) do
      match_data = Regexp.last_match
      label = match_data[1]

      # すでに処理済みのパターンはスキップ
      next if label =~ %r{^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}$}
      next if label =~ /^[0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日$/
      next if label =~ /^[0-9]{4}年?$/
      next if %W[\u7D50\u6210\u6642 \u73FE\u5728].include?(label)

      start_pos = match_data.end(0)
      content = extract_section_content(start_pos)

      sections << {
        date: nil,
        label: label,
        content: content,
        position: match_data.begin(0)
      }
    end

    # ラベルなしの !!メンバー セクション（現在のメンバーとみなす）
    @original_content.scan(/^!!メンバーー?(?!（)(?!\()\s*$/m) do
      match_data = Regexp.last_match
      start_pos = match_data.end(0)
      content = extract_section_content(start_pos)

      sections << {
        date: nil,
        label: nil,
        content: content,
        position: match_data.begin(0),
        current: true
      }
    end
  end

  def extract_named_pattern(sections, pattern_label, display_label, current: false)
    @original_content.scan(/^!!メンバーー?(?:（|\()#{pattern_label}(?:）|\))/m) do
      match_data = Regexp.last_match
      start_pos = match_data.end(0)
      content = extract_section_content(start_pos)

      sections << {
        date: nil,
        label: display_label,
        content: content,
        position: match_data.begin(0),
        current: current
      }
    end
  end

  def add_section(sections, date_parts:, content:, position:)
    year = date_parts[:year]
    month = date_parts[:month]
    day = date_parts[:day]
    # 日付のバリデーション
    if Date.valid_date?(year, month, day)
      sections << {
        date: Date.new(year, month, day),
        label: "#{year}/#{month}/#{day}",
        content: content,
        position: position
      }
    else
      # 無効な日付の場合も label のみで保存
      puts "[INVALID_DATE] #{year}/#{month}/#{day} in WikiID: #{@wikipage.id} - saving with label only"
      sections << {
        date: nil,
        label: "#{year}/#{month}/#{day}",
        content: content,
        position: position
      }
    end
  end

  # セクションの内容を抽出（次の !! または文末まで）
  def extract_section_content(start_pos)
    next_section = @original_content.index(/^!!/m, start_pos)
    if next_section
      @original_content[start_pos...next_section].strip
    else
      @original_content[start_pos..].strip
    end
  end

  # スナップショットを作成
  def create_snapshot(unit, section_data, snapshot_index)
    # 既存のスナップショットがあればスキップ
    if section_data[:date].present?
      existing = unit.unit_snapshots.find_by(snapshot_date: section_data[:date])
      if existing
        puts "  [SKIP] Snapshot already exists for #{unit.name} on #{section_data[:date]}"
        return
      end
    end

    # current = true の場合、既存の current スナップショットを false に更新
    is_current = section_data[:current] || false
    unit.unit_snapshots.where(current: true).update_all(current: false) if is_current

    snapshot = unit.unit_snapshots.create!(
      snapshot_date: section_data[:date],
      label: section_data[:label],
      current: is_current,
      snapshot_index: snapshot_index
    )

    # メンバーをパース
    parse_snapshot_members(snapshot, section_data[:content])

    date_str = section_data[:date]&.to_s || section_data[:label] || '現在のメンバー'
    puts "  [OK] Created snapshot for #{unit.name} on #{date_str} with #{snapshot.snapshot_people.count} members"
  end

  # スナップショットのメンバーをパース
  # 新旧フォーマットを混在で扱うため、全エントリをテキスト位置付きで収集し、出現順でソートしてから登録する
  def parse_snapshot_members(snapshot, content)
    return unless content

    # 一時的に @wiki_content を section content に置き換え
    original_wiki_content = @wiki_content
    @wiki_content = content

    separator_index = @wiki_content.index(/^!!関係者/) || Float::INFINITY

    # 全フォーマットのメンバーをテキスト位置付きで収集
    entries = []
    collect_new_format_entries(entries, separator_index)
    collect_old_format_entries(entries, separator_index)

    # テキスト上の出現順でソートし、sort_order を割り当てて登録
    entries.sort_by! { |e| e[:position] }
    entries.each_with_index do |entry, index|
      register_snapshot_member(snapshot, **entry.except(:position), sort_order: index + 1)
    end

    # @wiki_content を元に戻す
    @wiki_content = original_wiki_content
  end

  def collect_new_format_entries(entries, separator_index)
    extract_member_blocks.each do |block_data|
      current_pos = block_data[:begin]
      member_status = current_pos > separator_index ? :left : :active
      block_content = block_data[:content]

      if block_content.include?("\n")
        first_line, inline_history_text = block_content.split("\n", 2)
      else
        first_line = block_content
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

      entries << {
        position: current_pos,
        part_str: part_str,
        name_str: name_str,
        old_member_key: old_member_key,
        sns_account: sns_account,
        inline_history: inline_history,
        member_status: member_status
      }
    end
  end

  def collect_old_format_entries(entries, separator_index)
    old_member_regex1 = /^!([^…\n]+)…\s*\[\[([^|\]]+)(?:\|([^\]]+))?\]\]/
    old_member_regex2 = /^!\[\[([^|\]\n]+)(?:\|([^\]\n]+))?\]\]…([^…\n]+)/

    @wiki_content.scan(old_member_regex1) do |match|
      match_data = Regexp.last_match
      current_pos = match_data.begin(0)
      member_status = current_pos > separator_index ? :left : :active

      part_str = match[0].strip
      name_str = match[1].strip
      old_member_key = match[2]&.strip
      old_member_key = name_str if old_member_key.blank?
      old_member_key = URI.encode_www_form_component(old_member_key.encode('EUC-JP'))

      entries << {
        position: current_pos,
        part_str: part_str,
        name_str: name_str,
        old_member_key: old_member_key,
        sns_account: nil,
        inline_history: nil,
        member_status: member_status
      }
    end

    @wiki_content.scan(old_member_regex2) do |match|
      match_data = Regexp.last_match
      current_pos = match_data.begin(0)
      member_status = current_pos > separator_index ? :left : :active

      name_str = match[0].strip
      old_member_key = match[1]&.strip
      part_str = match[2].strip
      old_member_key = name_str if old_member_key.blank?
      old_member_key = URI.encode_www_form_component(old_member_key.encode('EUC-JP'))

      entries << {
        position: current_pos,
        part_str: part_str,
        name_str: name_str,
        old_member_key: old_member_key,
        sns_account: nil,
        inline_history: nil,
        member_status: member_status
      }
    end
  end

  # スナップショットメンバーを登録（新形式）
  def register_snapshot_member(snapshot, options = {})
    part_str = options[:part_str]
    name_str = options[:name_str]
    old_member_key = options[:old_member_key]
    sns_account = options[:sns_account]
    inline_history = options[:inline_history]
    member_status = options[:member_status]
    sort_order = options[:sort_order]

    # パートをパース
    part_enum = parse_part(part_str)
    support = part_str&.include?('サポート') || part_str&.include?('sup') || false

    # SNSをパース（V1と同じArray形式で保存）
    sns_data = sns_account.present? ? [sns_account.strip] : nil

    # Person を検索（old_person_key で検索）
    person = Person.find_by(old_key: old_member_key)

    snapshot.snapshot_people.create!(
      person: person,
      person_name: person ? nil : name_str,
      person_key: person&.key,
      old_person_key: old_member_key,
      part: part_enum,
      part_alias: part_str,
      status: member_status,
      support: support,
      sns: sns_data,
      inline_history: inline_history,
      sort_order: sort_order
    )
  end

  # パート文字列を enum に変換
  def parse_part(part_str)
    return :unknown if part_str.blank?

    part_lower = part_str.downcase
    case part_lower
    when /vo|vocal|ボーカル/
      :vocal
    when /gt|guitar|ギター/
      :guitar
    when /ba|bass|ベース/
      :bass
    when /dr|drum|ドラム/
      :drums
    when /key|keyboard|キーボード|piano|ピアノ/
      :keyboard
    when /dj/
      :dj
    else
      puts "[UNKNOWN_PART] '#{part_str}' in WikiID: #{@wikipage.id}"
      :unknown
    end
  end
end
# rubocop:enable Metrics/ClassLength

# frozen_string_literal: true

# WikipageImporterV2
# Extends WikipageImporter to parse dated member sections and create UnitSnapshot records
# Supports formats like:
# - !!メンバー（yyyy/mm/dd）
# - !!メンバー（yyyy年mm月dd日）
# - !!メンバー（結成時）
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

    # 日付付きメンバーセクションを抽出
    dated_sections = extract_dated_member_sections

    dated_sections.each do |section_data|
      create_snapshot(unit, section_data)
    end
  end

  # 日付付きメンバーセクションを抽出
  # 例: !!メンバー（2023/04/15）、!!メンバー（2023年4月15日）、!!メンバー（結成時）
  def extract_dated_member_sections
    return [] unless @original_content

    sections = []
    
    # パターン1: !!メンバー（yyyy/mm/dd）
    @original_content.scan(/^!!メンバー[ー]?(?:（|\\()([0-9]{4})\/([0-9]{1,2})\/([0-9]{1,2})(?:）|\\))/m) do
      match_data = Regexp.last_match
      year = match_data[1].to_i
      month = match_data[2].to_i
      day = match_data[3].to_i
      
      # 年が 0 の場合はサンプルテンプレートなのでスキップ
      next if year == 0
      
      # セクションの内容を抽出（次の !! まで）
      start_pos = match_data.end(0)
      content = extract_section_content(start_pos)
      
      # 日付のバリデーション
      if Date.valid_date?(year, month, day)
        sections << {
          date: Date.new(year, month, day),
          label: "#{year}/#{month}/#{day}",
          content: content,
          position: match_data.begin(0)
        }
      else
        # 無効な日付の場合も label のみで保存
        puts "[INVALID_DATE] #{year}/#{month}/#{day} in WikiID: #{@wikipage.id} - saving with label only"
        sections << {
          date: nil,
          label: "#{year}/#{month}/#{day}",
          content: content,
          position: match_data.begin(0)
        }
      end
    end

    # パターン2: !!メンバー（yyyy年mm月dd日）
    @original_content.scan(/^!!メンバー[ー]?(?:（|\\()([0-9]{4})年([0-9]{1,2})月([0-9]{1,2})日(?:）|\\))/m) do
      match_data = Regexp.last_match
      year = match_data[1].to_i
      month = match_data[2].to_i
      day = match_data[3].to_i
      
      # 年が 0 の場合はサンプルテンプレートなのでスキップ
      next if year == 0
      
      start_pos = match_data.end(0)
      content = extract_section_content(start_pos)
      
      # 日付のバリデーション
      if Date.valid_date?(year, month, day)
        sections << {
          date: Date.new(year, month, day),
          label: "#{year}年#{month}月#{day}日",
          content: content,
          position: match_data.begin(0)
        }
      else
        # 無効な日付の場合も label のみで保存
        puts "[INVALID_DATE] #{year}年#{month}月#{day}日 in WikiID: #{@wikipage.id} - saving with label only"
        sections << {
          date: nil,
          label: "#{year}年#{month}月#{day}日",
          content: content,
          position: match_data.begin(0)
        }
      end
    end

    # パターン3: !!メンバー（ラベルのみ）例: !!メンバー（結成時）
    @original_content.scan(/^!!メンバー[ー]?(?:（|\\()([^0-9）)]+)(?:）|\\))/m) do
      match_data = Regexp.last_match
      label_raw = match_data[1]
      next if label_raw.nil?
      
      label = label_raw.strip
      next if label.blank?
      
      start_pos = match_data.end(0)
      content = extract_section_content(start_pos)
      
      # ラベルのみの場合は、日付を nil にして label だけ設定
      # 後で手動で日付を設定してもらう
      sections << {
        date: nil,
        label: label,
        content: content,
        position: match_data.begin(0)
      }
    end

    # パターン4: !!メンバー（ラベルなし）→ 現在のメンバー (current = true)
    # 他のパターンにマッチしなかった !!メンバー セクションを検出
    @original_content.scan(/^!!メンバー[ー]?\s*$/m) do
      match_data = Regexp.last_match
      start_pos = match_data.end(0)
      content = extract_section_content(start_pos)
      
      # 既に同じ位置のセクションが追加されていないかチェック
      already_added = sections.any? { |s| s[:position] == match_data.begin(0) }
      next if already_added
      
      sections << {
        date: nil,
        label: nil,
        content: content,
        position: match_data.begin(0),
        current: true
      }
    end

    sections
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
  def create_snapshot(unit, section_data)
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
    if is_current
      unit.unit_snapshots.where(current: true).update_all(current: false)
    end

    snapshot = unit.unit_snapshots.create!(
      snapshot_date: section_data[:date],
      label: section_data[:label],
      current: is_current
    )

    # メンバーをパース
    parse_snapshot_members(snapshot, section_data[:content])

    date_str = section_data[:date]&.to_s || section_data[:label] || '現在のメンバー'
    puts "  [OK] Created snapshot for #{unit.name} on #{date_str} with #{snapshot.snapshot_people.count} members"
  end

  # スナップショットのメンバーをパース
  def parse_snapshot_members(snapshot, content)
    return unless content

    # 一時的に @wiki_content を section content に置き換え
    original_wiki_content = @wiki_content
    @wiki_content = content

    separator_index = @wiki_content.index(/^!!関係者/) || Float::INFINITY
    current_order = 1

    # Plugin format - use balanced bracket matching
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

      register_snapshot_member(snapshot, part_str, name_str, old_member_key, sns_account, inline_history, member_status, current_order)
      current_order += 1
    end

    # Old Member Format
    old_member_regex1 = /^!([^…\n]+)…\s*\[\[([^|\]]+)(?:\|([^\]]+))?\]\]/
    old_member_regex2 = /^!\[\[([^|\]\n]+)(?:\|([^\]\n]+))?\]\]…([^…\n]+)/

    @wiki_content.scan(old_member_regex1) do |match|
      match_data = Regexp.last_match
      current_pos = match_data.begin(0)
      member_status = current_pos > separator_index ? :left : :active

      part_str = match[0].strip
      name_str = match[1].strip
      old_member_key = match[2]&.strip

      register_snapshot_member_old_format(snapshot, part_str, name_str, old_member_key, member_status, current_order)
      current_order += 1
    end

    @wiki_content.scan(old_member_regex2) do |match|
      match_data = Regexp.last_match
      current_pos = match_data.begin(0)
      member_status = current_pos > separator_index ? :left : :active

      name_str = match[0].strip
      old_member_key = match[1]&.strip
      part_str = match[2].strip

      register_snapshot_member_old_format(snapshot, part_str, name_str, old_member_key, member_status, current_order)
      current_order += 1
    end

    # @wiki_content を元に戻す
    @wiki_content = original_wiki_content
  end

  # スナップショットメンバーを登録（新形式）
  # rubocop:disable Metrics/ParameterLists
  def register_snapshot_member(snapshot, part_str, name_str, old_member_key, sns_account, inline_history, member_status, sort_order)
    # パートをパース
    part_enum = parse_part(part_str)
    support = part_str&.include?('サポート') || part_str&.include?('sup') || false

    # SNSをパース
    sns_data = parse_sns(sns_account)

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
  # rubocop:enable Metrics/ParameterLists

  # スナップショットメンバーを登録（旧形式）
  def register_snapshot_member_old_format(snapshot, part_str, name_str, old_member_key, member_status, sort_order)
    old_member_key = name_str if old_member_key.blank?
    old_member_key = URI.encode_www_form_component(old_member_key.encode('EUC-JP'))

    part_enum = parse_part(part_str)
    support = part_str&.include?('サポート') || part_str&.include?('sup') || false

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
      sort_order: sort_order
    )
  end

  # パート文字列を enum に変換
  def parse_part(part_str)
    return :unknown if part_str.blank?

    part_lower = part_str.downcase
    result = case part_lower
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
    result
  end

  # SNS文字列をJSONに変換
  def parse_sns(sns_str)
    return nil if sns_str.blank?

    # 簡易的なパース（例: "twitter:account" 形式）
    sns_data = {}
    sns_str.split(',').each do |item|
      parts = item.strip.split(':', 2)
      next if parts.size != 2

      service = parts[0].strip.downcase
      account = parts[1].strip
      sns_data[service] = account
    end

    sns_data.empty? ? nil : sns_data
  end
end

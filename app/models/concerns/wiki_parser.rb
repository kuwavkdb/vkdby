# frozen_string_literal: true

module WikiParser # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  # 履歴文字列をパースして構造化データの配列を返す
  # 戻り値: [
  #   [
  #     { unit_name: "ユニット名", part_and_name: "Part" or "Part+PersonName" or "PersonName",
  #       old_key: "EUC-JPエンコードされたユニット名", external_url: "外部URL",
  #       internal_url: "サイト内相対パス", note: "備考(日付など)" },
  #     ... (同時期の活動)
  #   ],
  #   ...
  # ]
  def parse_history_string(history_text) # rubocop:disable Metrics/PerceivedComplexity, Metrics/AbcSize
    return [] if history_text.blank?

    # Filter out comment lines starting with //
    clean_history_text = history_text.lines
                                     .reject { |line| line.strip.start_with?('//') }
                                     .map(&:strip)
                                     .join

    timeline = []

    # Split by → and process each period (括弧内の→は区切りとしない)
    split_top_level(clean_history_text, '→').each do |period_segment|
      concurrent_items = []

      # Split by 、 to handle concurrent activities (括弧内の、は区切りとしない)
      split_top_level(period_segment, '、').each do |item_segment|
        metadata = { notes: [] }
        item_segment = process_plugins(item_segment.strip, metadata)
        next if item_segment.empty? && metadata[:notes].empty?

        # Check if the entire segment is wrapped in parentheses
        wrapped_in_parens = item_segment.start_with?('(') && item_segment.end_with?(')')

        # Remove outer parentheses for pattern matching if wrapped
        # Remove outer parentheses for pattern matching if wrapped
        content = wrapped_in_parens ? item_segment[1..-2] : item_segment

        case content
        # Pattern 1: [[UnitName]] or [[UnitName]](Part) or [[UnitName]]Role - Internal unit link
        when /\[\[([^\]]+)\]\](?:\(([^)]+)\))?/
          unit_text = ::Regexp.last_match(1)
          part_and_name = ::Regexp.last_match(2)

          # [[バンド名]]ローディー のように括弧なしで役割テキストが続く場合に取り込む
          unless part_and_name
            trailing = content[::Regexp.last_match(0).length..].strip
            part_and_name = trailing.presence
          end

          # [[XXXX|YYYY]] の場合、XXXXが表示名、YYYYがold_key(エンコード前)
          if unit_text.include?('|')
            display_name, raw_old_key = unit_text.split('|', 2)
          else
            display_name = unit_text
            raw_old_key = unit_text
          end

          # old_key生成用にEUC-JPエンコード
          encoded_unit_name = encode_euc_jp(raw_old_key.strip)

          # If wrapped in parentheses, add them to display
          display_unit_name = wrapped_in_parens ? "(#{display_name.strip})" : display_name.strip

          concurrent_items << {
            unit_name: display_unit_name,
            part_and_name: part_and_name&.strip,
            old_key: encoded_unit_name,
            notes: metadata[:notes]
          }
        # Pattern 1b: [Label](target) or [Label](target)(Part) - Markdown形式のリンク
        # （CustomPageDraftGeneratorが旧[[Label|target]]記法から変換した経歴テキストなどで使用される。
        # targetが"/xxx"のようなサイト内相対パスの場合はinternal_url、それ以外はexternal_urlとして扱う）
        # Label に | を含む場合はPattern 2（旧wikiのパイプ外部リンク）を優先させるため除外する
        when /\[([^\]|]+)\]\(([^)]+)\)(?:\(([^)]+)\))?/
          link_text = ::Regexp.last_match(1)
          target = ::Regexp.last_match(2).strip
          part_and_name = ::Regexp.last_match(3)

          display_link_text = wrapped_in_parens ? "(#{link_text.strip})" : link_text.strip

          concurrent_items << {
            unit_name: display_link_text,
            part_and_name: part_and_name&.strip,
            **link_url_attribute(target),
            notes: metadata[:notes]
          }
        # Pattern 2: [LinkText|URL] or [LinkText|URL](Part) - External link
        # （URLがサイト内相対パスの場合はinternal_urlとして扱う）
        when /\[([^\]|]+)\|([^\]]+)\](?:\(([^)]+)\))?/
          link_text = ::Regexp.last_match(1)
          url = ::Regexp.last_match(2).strip
          part_and_name = ::Regexp.last_match(3)

          # If wrapped in parentheses, add them to display
          display_link_text = wrapped_in_parens ? "(#{link_text.strip})" : link_text.strip

          concurrent_items << {
            unit_name: display_link_text,
            part_and_name: part_and_name&.strip,
            **link_url_attribute(url),
            notes: metadata[:notes]
          }
        # Pattern 3: Plain text - No link, display as-is (including parentheses)
        else
          concurrent_items << {
            unit_name: item_segment.strip,
            notes: metadata[:notes],
            is_temp: metadata[:is_temp]
          }
        end
      end

      timeline << concurrent_items if concurrent_items.any?
    end

    timeline
  end

  private

  # リンク先がサイト内の相対パスならinternal_url、それ以外（外部URL）ならexternal_urlとして
  # ハッシュを組み立てる。表示側（profiles/show.html.erb, history_row_component.html.erb）は
  # internal_urlの場合は外部リンクアイコン・target="_blank"を付けずにサイト内リンクとして描画する
  def link_url_attribute(url)
    SiteLinkClassifier.relative_or_safe_link?(url) ? { internal_url: url } : { external_url: url }
  end

  def process_plugins(text, metadata = {})
    text.gsub(/\{\{([^}]+)\}\}/) do |match|
      content = ::Regexp.last_match(1).strip
      plugin_name, plugin_value = content.split(' ', 2)
      plugin_name = plugin_name&.downcase

      case plugin_name
      when 'tweet'
        ''
      when 'fn'
        metadata[:notes] << plugin_value&.strip if plugin_value.present?
        ''
      when 'category'
        metadata[:notes] << plugin_value&.strip if plugin_value.present?
        ''
      when 'temp'
        if plugin_value&.include?(',')
          name_part, badge_part = plugin_value.split(',', 2).map(&:strip)
        else
          name_part = plugin_value&.strip
          badge_part = nil
        end
        metadata[:notes] << badge_part if badge_part.present?
        metadata[:is_temp] = true
        name_part
      when 'rb'
        if plugin_value&.include?(',')
          text_part, ruby_part = plugin_value.split(',', 2).map(&:strip)
          "<ruby>#{text_part}<rt>#{ruby_part}</rt></ruby>"
        else
          plugin_value
        end
      else
        match
      end
    end.strip
  end

  # 指定の区切り文字で分割するが、括弧()・角括弧[[]]・波括弧{{}}内の区切り文字は無視する
  def split_top_level(text, delimiter)
    segments = []
    current = +''
    paren_depth = 0
    bracket_depth = 0
    brace_depth = 0

    text.each_char do |char|
      case char
      when '(' then paren_depth += 1
      when ')' then paren_depth -= 1 if paren_depth.positive?
      when '[' then bracket_depth += 1
      when ']' then bracket_depth -= 1 if bracket_depth.positive?
      when '{' then brace_depth += 1
      when '}' then brace_depth -= 1 if brace_depth.positive?
      end

      if char == delimiter && paren_depth.zero? && bracket_depth.zero? && brace_depth.zero?
        segments << current
        current = +''
      else
        current << char
      end
    end
    segments << current
    segments
  end

  def encode_euc_jp(str)
    # DBのold_key（URI.encode_www_form_component形式）との対応関係：
    #   space(0x20)              → + （DBの+と一致）
    #   高ビット(>0x7F, EUC-JP) → %XX （ミドルウェアが%25XXに二重エンコード → Railsデコード後%XX → DBと一致）
    #   [A-Za-z0-9\-_.*]        → %XX （Railsがデコードした文字 → DBの文字と一致）
    #   その他ASCII特殊文字      → %25XX （Railsが%25→%にデコード → 結果%XX → DBのリテラル%XXと一致）
    str.encode('EUC-JP').bytes.map do |b|
      if b == 0x20
        '+'
      elsif b > 0x7F
        "%#{b.to_s(16).upcase}"
      elsif (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) ||
            (b >= 0x30 && b <= 0x39) ||
            [0x2D, 0x5F, 0x2E, 0x2A].include?(b) # - _ . *
        "%#{b.to_s(16).upcase}"
      else
        # URI.encode_www_form_componentがエンコードする特殊ASCII文字（'など）
        # %25XX → Railsルーティングで%→ 結果%XX → DBのリテラル%XXと一致
        "%25#{b.to_s(16).upcase}"
      end
    end.join
  rescue Encoding::UndefinedConversionError
    # Fallback if conversion fails
    str
  end
end

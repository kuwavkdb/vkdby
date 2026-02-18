# frozen_string_literal: true

module WikiParser # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  # 履歴文字列をパースして構造化データの配列を返す
  # 戻り値: [
  #   [
  #     { unit_name: "ユニット名", part_and_name: "Part" or "Part+PersonName" or "PersonName",
  #       old_key: "EUC-JPエンコードされたユニット名", external_url: "外部URL", note: "備考(日付など)" },
  #     ... (同時期の活動)
  #   ],
  #   ...
  # ]
  def parse_history_string(history_text) # rubocop:disable Metrics/PerceivedComplexity
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
        # Pattern 1: [[UnitName]] or [[UnitName]](Part) - Internal unit link
        when /\[\[([^\]]+)\]\](?:\(([^)]+)\))?/
          unit_text = ::Regexp.last_match(1)
          part_and_name = ::Regexp.last_match(2)

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
        # Pattern 2: [LinkText|URL] or [LinkText|URL](Part) - External link
        when /\[([^\]|]+)\|([^\]]+)\](?:\(([^)]+)\))?/
          link_text = ::Regexp.last_match(1)
          url = ::Regexp.last_match(2)
          part_and_name = ::Regexp.last_match(3)

          # If wrapped in parentheses, add them to display
          display_link_text = wrapped_in_parens ? "(#{link_text.strip})" : link_text.strip

          concurrent_items << {
            unit_name: display_link_text,
            part_and_name: part_and_name&.strip,
            external_url: url.strip,
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
    str.encode('EUC-JP').bytes.map { |b| "%#{b.to_s(16).upcase}" }.join
  rescue Encoding::UndefinedConversionError
    # Fallback if conversion fails
    str
  end
end

# frozen_string_literal: true

module TrendsHelper
  # Trend#units / Trend#people の jsonb に保存されたスナップショット時点の名前を優先し、
  # 無ければ現在の Unit / Person の名前にフォールバックする
  def trend_unit_display_name(unit_data, unit)
    unit_data['name'].presence || unit&.name
  end

  def trend_person_display_name(person_data, person)
    person_data['name'].presence || person&.name
  end

  # Trend詳細ページのヘッダに表示している日付ラベルを返す（issue #1313）
  def trend_date_label(trend)
    if trend.month_unknown?
      trend.date.strftime('%Y')
    elsif trend.day_unknown?
      trend.date.strftime('%Y/%m')
    else
      trend.date.strftime('%Y/%m/%d')
    end
  end

  # X（Twitter）へのシェア用テキストを生成する（issue #1313）
  # ヘッダに表示している内容（日付・Units・タイトル・People）＋ TrendのURL ＋ ハッシュタグ #vkdb
  def trend_x_share_text(trend, related_units: {}, related_people: {})
    unit_names = (trend.units || []).filter_map do |unit_data|
      trend_unit_display_name(unit_data, related_units[unit_data['unit_id']])
    end
    person_names = (trend.people || []).filter_map do |person_data|
      trend_person_display_name(person_data, related_people[person_data['person_id']])
    end
    title = strip_tags(format_wiki_title(trend.title, link: false)).presence

    lines = [[trend_date_label(trend), *unit_names, title].compact_blank.join(' ')]
    lines << person_names.join(' ') if person_names.any?
    lines << trend_url(trend)
    lines << '#vkdb'
    lines.join("\n")
  end

  def twitter_url?(url)
    return false if url.blank?

    url.match?(Link::TWITTER_STATUS_URL_PATTERN)
  end

  def twitter_embed(_url, quote)
    html = <<~HTML
      #{quote}
      <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
    HTML
    html.html_safe
  end

  # Sanitize URL to prevent XSS attacks
  # Only allow http:// and https:// schemes
  def safe_url(url)
    return nil if url.blank?

    url_string = url.to_s
    url_string.start_with?('http://', 'https://') ? url_string : nil
  end
end

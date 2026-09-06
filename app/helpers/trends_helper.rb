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

  # trends/show のヘッダで、件名（h1）の前に個人名バッヂを表示すべきかどうか（issue #1411）。
  # 個人の動向種別（person_phenomenon）が設定されていて、かつユニットと紐づいていない
  # （units が空）場合のみ、ユニットバッヂと同じ位置に個人名を表示する
  def trend_show_person_badge_in_title?(trend)
    trend.units.blank? && trend.person_phenomenon.present? && trend.people.present?
  end

  # ページ<title>/og:title/twitter:title用にタイトル末尾の半角括弧書き（会場名等の補足）を取り除く（issue #1319）。
  # 正規表現自体はTrend#ogp_image_attachable_textと共有（Trend::TITLE_TRAILING_PARENTHETICAL_PATTERN）
  def trend_title_without_trailing_parenthetical(text)
    text.to_s.sub(Trend::TITLE_TRAILING_PARENTHETICAL_PATTERN, '')
  end

  # Trend詳細ページのヘッダに表示している日付ラベルを返す（issue #1313）。
  # ロジック本体はTrend#date_labelに集約（ページ<title>・OGP画像でも使うため、issue #1319）
  def trend_date_label(trend)
    trend.date_label
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

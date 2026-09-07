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

  # trends/show のヘッダで、件名（h1）の前に個人名バッヂを表示すべきかどうか。
  # trend.person_name_in_title（issue #1419）が設定されていれば動向種別の内容に関わらず
  # それを最優先し、未設定の場合は#1411までの自動判定（個人の動向種別が設定されていて、
  # かつユニットと紐づいていない場合のみ個人名を表示）にフォールバックする
  def trend_show_person_badge_in_title?(trend)
    return trend.people.present? if trend.person_name_in_title?

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
  # trend_show_person_badge_in_title?と同じ判定で、件名前に個人名を出す設定の場合は
  # 1行目を個人名、2行目をユニット名に入れ替える（issue #1419）
  def trend_x_share_text(trend, related_units: {}, related_people: {})
    # 複数のユニット名／個人名が紐づく場合、それぞれ間を「、」区切りにする
    unit_names = (trend.units || []).filter_map do |unit_data|
      trend_unit_display_name(unit_data, related_units[unit_data['unit_id']])
    end.join('、').presence
    person_names = (trend.people || []).filter_map do |person_data|
      trend_person_display_name(person_data, related_people[person_data['person_id']])
    end.join('、').presence
    title = strip_tags(format_wiki_title(trend.title, link: false)).presence
    primary_name, secondary_name = trend_show_person_badge_in_title?(trend) ? [person_names, unit_names] : [unit_names, person_names]

    lines = [[trend_date_label(trend), primary_name, title].compact_blank.join(' ')]
    lines << secondary_name if secondary_name.present?
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

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

  # 動向に紐づくユニットのうち、Unitレコードが無く名前だけ保存されているもののバッジ。
  # trends/index・daily・monthly・yearlyで同じ<span>をコピーしていたため集約した（issue #1672）。
  # 公開側のグレーはzincにそろえる方針（issue #1667）
  UNIT_NAME_BADGE_CLASS = 'inline-block px-2 py-0.5 rounded text-sm font-semibold ' \
                          'bg-zinc-50 text-zinc-700 border border-zinc-200 ' \
                          'dark:bg-zinc-800 dark:text-zinc-300 dark:border-zinc-600 mr-1'

  def unit_name_badge(name)
    tag.span(name, class: UNIT_NAME_BADGE_CLASS)
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

  # 末尾の括弧書き（半角・全角）。Trend::TITLE_TRAILING_PARENTHETICAL_PATTERNは半角のみのため別に持つ
  TITLE_TRAILING_ANY_PARENTHETICAL_PATTERN = /\s*[(（][^()（）]*[)）]\z/
  ON_THIS_DAY_SHARE_TREND_COUNT = 3
  ON_THIS_DAY_SHARE_BIRTHDAY_COUNT = 3

  # 年指定なしの日付ページ（/date/-/:month/:day）の「今日はなんの日？」シェア用テキスト（issue #1732）。
  # 表示中の動向からランダムに3件選び、ページと同じく「年 ユニット名 タイトル」を1行にする
  # （4件以上あれば「・他」を付ける）。タイトル末尾の括弧書き（会場名等の補足）は除去する。
  # 動向が3件未満の場合は、誕生日の人物を最大3件ランダムに「誕生日: A、B、C、他」として加える
  def on_this_day_share_text(trends, month:, day:, birthdays: [], related_units: {})
    trends = trends.to_a
    lines = ['ヴィジュアル系今日はなんの日？']
    trends.sample(ON_THIS_DAY_SHARE_TREND_COUNT).sort_by(&:date).each do |trend|
      lines << "・#{on_this_day_share_trend_line(trend, related_units)}"
    end
    lines << '・他' if trends.size > ON_THIS_DAY_SHARE_TREND_COUNT
    if trends.size < ON_THIS_DAY_SHARE_TREND_COUNT
      birthday_line = on_this_day_share_birthday_line(birthdays.to_a)
      lines << birthday_line if birthday_line
    end
    lines << birthday_date_url(month: month, day: day)
    lines << '#vkdb'
    lines.join("\n")
  end

  def twitter_url?(url)
    return false if url.blank?

    url.match?(Link::TWITTER_STATUS_URL_PATTERN)
  end

  # Xの oEmbed HTML（<blockquote class="twitter-tweet">…）で使うタグ・属性。quoteは管理画面の入力や
  # trend-urlスキルの事前入力で入るため、これ以外（<script>、javascript: の href など）は取り除く（issue #1707）
  TWITTER_EMBED_TAGS = %w[blockquote p a br].freeze
  TWITTER_EMBED_ATTRIBUTES = %w[class lang dir href data-lang data-theme data-dnt data-conversation data-cards
                                data-width data-align].freeze

  def twitter_embed(_url, quote)
    safe_join([
                sanitize(quote, tags: TWITTER_EMBED_TAGS, attributes: TWITTER_EMBED_ATTRIBUTES),
                tag.script(async: true, src: 'https://platform.twitter.com/widgets.js', charset: 'utf-8')
              ], "\n")
  end

  # Sanitize URL to prevent XSS attacks
  # Only allow http:// and https:// schemes
  def safe_url(url)
    return nil if url.blank?

    url_string = url.to_s
    url_string.start_with?('http://', 'https://') ? url_string : nil
  end

  private

  def on_this_day_share_trend_line(trend, related_units)
    unit_names = (trend.units || []).filter_map do |unit_data|
      trend_unit_display_name(unit_data, related_units[unit_data['unit_id']])
    end.join('、')
    title = trend.title_as_plain_text.sub(TITLE_TRAILING_ANY_PARENTHETICAL_PATTERN, '')
    ["#{trend.date.year}年", unit_names, title].compact_blank.join(' ')
  end

  # 表示順（ヨミガナ順）は保ったままランダムに選ぶ
  def on_this_day_share_birthday_line(birthdays)
    return if birthdays.empty?

    names = birthdays.each_with_index.to_a.sample(ON_THIS_DAY_SHARE_BIRTHDAY_COUNT).sort_by(&:last).map { |person, _| person.name }
    names << '他' if birthdays.size > ON_THIS_DAY_SHARE_BIRTHDAY_COUNT
    "誕生日: #{names.join('、')}"
  end
end

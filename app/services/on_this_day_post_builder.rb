# frozen_string_literal: true

# 「今日は何の日？」ページ（/date/-/:month/:day）の紹介ポスト文を作る（issue #1742、#1753）。
# GitHub の Issue にコメントする投稿文（通常は前日の夜に翌日分、.github/workflows/on_this_day.yml）で、出来事（動向）と誕生日の2件に分ける。
# 投稿は手動で、載せるものはその場で取捨選択するため、X の上限280文字（重み付き、XPostLength）に関係なく
# その日の動向・誕生日をすべて載せる（issue #1848）。
#
# 出来事の投稿
# - 動向を年の古い順に1件1行で並べる
# - 冒頭の見出しはハッシュタグ（#ヴィジュアル系今日は何の日？）にし、末尾に #vkdb は付けない
#
# 誕生日の投稿
# - ヨミガナ順に1人1行で並べる
# - 人物名の後に、経歴で最後に書かれたユニット名（その後に「→」があれば ex-ユニット名）を括弧書きで付ける（PersonUnitLabel）
# - 末尾にハッシュタグ #vkdb を付ける
#
# 管理画面のシェア用テキスト（TrendsHelper#on_this_day_share_text、issue #1732）とは別のルールで、
# そちらには適用しない
class OnThisDayPostBuilder
  HEADER = '#ヴィジュアル系今日は何の日？'
  TIME_ZONE = 'Asia/Tokyo'
  # 年を問わない日付（MM-DD）を Date にするときの年。2/29 も扱えるよううるう年にする
  MONTH_DAY_YEAR = 2000
  MONTH_DAY_PATTERN = %r{\A(\d{1,2})[-/](\d{1,2})\z}
  HASHTAG = '#vkdb'
  # 出来事の投稿のリンク先に付けるページ内リンク（日付ページの動向セクション）
  TRENDS_ANCHOR = 'trends'
  # 末尾の括弧書き（半角・全角）。会場名等の補足を除く
  TITLE_TRAILING_PARENTHETICAL_PATTERN = /\s*[(（][^()（）]*[)）]\z/

  # JST の当日
  def self.today
    Time.find_zone(TIME_ZONE).today
  end

  # "MM-DD"（"M/D" も可）を Date にする。年は使わないため MONTH_DAY_YEAR で固定。不正なら nil
  def self.parse_month_day(value)
    match = MONTH_DAY_PATTERN.match(value.to_s.strip)
    return nil unless match

    Date.new(MONTH_DAY_YEAR, match[1].to_i, match[2].to_i)
  rescue Date::Error
    nil
  end

  def initialize(date)
    @date = date
  end

  # OnThisDayPost の配列（出来事、誕生日の順）を返す。載せる内容がない投稿は含めない（両方なければ空配列）
  def build
    [build_trend_post, build_birthday_post].compact
  end

  # 当日の「今日は何の日？」ページのURL（https）
  def page_url
    return @page_url if @page_url

    url_options = (Rails.application.config.action_mailer.default_url_options || {}).merge(protocol: 'https')
    @page_url = Rails.application.routes.url_helpers.birthday_date_url(month: @date.month, day: @date.day, **url_options)
  end

  private

  def build_trend_post
    return nil if trends.empty?

    OnThisDayPost.new(kind: :trends, date: @date, text: compose_trends, page_url: trends_page_url)
  end

  def build_birthday_post
    return nil if birthdays.empty?

    OnThisDayPost.new(kind: :birthdays, date: @date, text: compose_birthdays, page_url: page_url)
  end

  # 出来事の投稿のリンク先。動向セクションへのページ内リンクを付ける
  def trends_page_url
    "#{page_url}##{TRENDS_ANCHOR}"
  end

  def trends
    @trends ||= Trend.published.on_month_day(@date.month, @date.day)
                     .select(:id, :date, :title, :units).to_a
  end

  def birthdays
    @birthdays ||= Person.kept.published.birthday_on(@date).order(name_kana: :asc)
                         .select(:id, :name, :old_history).to_a
  end

  def compose_trends
    lines = ["#{HEADER}（#{month_day}）"]
    lines.concat(trends.sort_by(&:date).map { |trend| "・#{trend_line(trend)}" })
    compose(lines, trends_page_url, hashtag: nil)
  end

  def compose_birthdays
    lines = ["今日（#{month_day}）誕生日のヴィジュアル系アーティスト"]
    lines.concat(birthdays.map { |person| birthday_line(person) })
    compose(lines, page_url)
  end

  def compose(lines, url, hashtag: HASHTAG)
    (lines + [url, hashtag]).compact.join("\n")
  end

  def month_day
    "#{@date.month}/#{@date.day}"
  end

  def trend_line(trend)
    unit_names = (trend.units || []).filter_map do |unit_data|
      unit_data['name'].presence || related_units[unit_data['unit_id'].to_i]&.name
    end.join('、')
    title = trend.title_as_plain_text.sub(TITLE_TRAILING_PARENTHETICAL_PATTERN, '')
    ["#{trend.date.year}年", unit_names, title].compact_blank.join(' ')
  end

  def birthday_line(person)
    label = PersonUnitLabel.new(person).call
    label ? "・#{person.name}（#{label}）" : "・#{person.name}"
  end

  def related_units
    @related_units ||= begin
      ids = trends.flat_map { |trend| (trend.units || []).filter_map { |u| u['unit_id'].presence&.to_i } }.uniq
      Unit.publicly_visible.where(id: ids).select(:id, :name).index_by(&:id)
    end
  end
end

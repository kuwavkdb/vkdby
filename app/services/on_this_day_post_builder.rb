# frozen_string_literal: true

# 「今日は何の日？」ページ（/date/-/:month/:day）の紹介ポスト文を作る（issue #1742、#1753）。
# GitHub の Issue にコメントする投稿文（通常は前日の夜に翌日分、.github/workflows/on_this_day.yml）で、出来事（動向）と誕生日の2件に分ける。
# それぞれ X の上限280文字（重み付き、XPostLength）に収める。
#
# 出来事の投稿
# - OnThisDayTrendRanker の優先順位（解散・活動休止・メジャーデビュー・結成・初ライブ・活動再開を優先し、
#   その中でメジャー経験バンドを先にする。同じ優先度の中はランダム）の高いものから、入るだけ選ぶ。1バンド1件まで
# - 入りきらなかった動向があれば「・他」を付ける
# - 冒頭の見出しはハッシュタグ（#ヴィジュアル系今日は何の日？）にし、末尾に #vkdb は付けない
#
# 誕生日の投稿
# - ランダムに選んで入るだけ、ヨミガナ順に1人1行で並べる。入りきらなかった人がいれば「・他」を付ける
# - 人物名の後に、経歴で最後に書かれたユニット名（その後に「→」があれば ex-ユニット名）を括弧書きで付ける（PersonUnitLabel）
# - 末尾にハッシュタグ #vkdb を付ける
#
# 管理画面のシェア用テキスト（TrendsHelper#on_this_day_share_text、issue #1732）とは別のルールで、
# そちらには適用しない
class OnThisDayPostBuilder # rubocop:disable Metrics/ClassLength
  HEADER = '#ヴィジュアル系今日は何の日？'
  TIME_ZONE = 'Asia/Tokyo'
  # 年を問わない日付（MM-DD）を Date にするときの年。2/29 も扱えるよううるう年にする
  MONTH_DAY_YEAR = 2000
  MONTH_DAY_PATTERN = %r{\A(\d{1,2})[-/](\d{1,2})\z}
  HASHTAG = '#vkdb'
  # 出来事の投稿のリンク先に付けるページ内リンク（日付ページの動向セクション）
  TRENDS_ANCHOR = 'trends'
  OTHERS_LINE = '・他'
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

  def initialize(date, random: Random.new)
    @date = date
    @random = random
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

    selected = select_trends
    text = compose_trends(selected, trends.size > selected.size)
    OnThisDayPost.new(kind: :trends, date: @date, text: text, page_url: trends_page_url)
  end

  def build_birthday_post
    return nil if birthdays.empty?

    selected = select_birthdays
    return nil if selected.empty?

    text = compose_birthdays(selected, birthdays.size > selected.size)
    OnThisDayPost.new(kind: :birthdays, date: @date, text: text, page_url: page_url)
  end

  # 出来事の投稿のリンク先。動向セクションへのページ内リンクを付ける
  def trends_page_url
    "#{page_url}##{TRENDS_ANCHOR}"
  end

  def trends
    @trends ||= Trend.published.on_month_day(@date.month, @date.day)
                     .select(:id, :date, :title, :units, :unit_phenomenon).to_a
  end

  def birthdays
    @birthdays ||= Person.kept.published.birthday_on(@date).order(name_kana: :asc)
                         .select(:id, :name, :old_history).to_a
  end

  # 優先順位の高い候補から順に、280文字に収まるものを選ぶ（1バンド1件まで）
  def select_trends
    selected = []
    used_unit_keys = Set.new
    OnThisDayTrendRanker.new(trends, random: @random).ranked.each do |trend|
      keys = OnThisDayTrendRanker.unit_keys(trend)
      next if keys.intersect?(used_unit_keys)

      candidate = selected + [trend]
      next unless XPostLength.fits?(compose_trends(candidate, trends.size > candidate.size))

      selected = candidate
      used_unit_keys.merge(keys)
    end
    selected
  end

  # ランダムな順に、280文字に収まる人を選ぶ。戻り値は [行, ヨミガナ順の位置] の配列
  def select_birthdays
    selected = []
    birthdays.each_with_index.to_a.shuffle(random: @random).each do |person, index|
      candidate = selected + [[birthday_line(person), index]]
      next unless XPostLength.fits?(compose_birthdays(candidate, birthdays.size > candidate.size))

      selected = candidate
    end
    selected
  end

  def compose_trends(selected, others)
    lines = ["#{HEADER}（#{month_day}）"]
    lines.concat(selected.sort_by(&:date).map { |trend| "・#{trend_line(trend)}" })
    lines << OTHERS_LINE if others
    compose(lines, trends_page_url, hashtag: nil)
  end

  def compose_birthdays(selected, others)
    lines = ["今日（#{month_day}）誕生日のヴィジュアル系アーティスト"]
    lines.concat(selected.sort_by(&:last).map(&:first))
    lines << OTHERS_LINE if others
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
    @birthday_lines ||= {}
    @birthday_lines[person.id] ||= begin
      label = PersonUnitLabel.new(person).call
      label ? "・#{person.name}（#{label}）" : "・#{person.name}"
    end
  end

  def related_units
    @related_units ||= begin
      ids = trends.flat_map { |trend| OnThisDayTrendRanker.unit_ids(trend).to_a }.uniq
      Unit.publicly_visible.where(id: ids).select(:id, :name).index_by(&:id)
    end
  end
end

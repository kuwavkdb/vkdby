# frozen_string_literal: true

# 「今日はなんの日？」ページ（/date/-/:month/:day）の紹介ポスト文を作る（issue #1742）。
# 毎日0時（JST）に管理者へメールする投稿文で、X の上限280文字（重み付き、XPostLength）に収める。
#
# - 動向は最大5件。OnThisDayTrendRanker の優先順位（解散・活動休止を最優先し、その中でメジャー経験バンドを
#   先にする。同じ優先度の中はランダム）の高いものから選ぶ。1バンド1件まで
# - 入りきらなかった動向があれば「・他」を付ける
# - 文字数に余裕があれば、誕生日の人物を入るだけ「誕生日: A、B、他」として加える。2人以上入らない場合は
#   行ごと省く（誕生日の人物が1人だけの日は、その1人が入れば載せる）
#
# 管理画面のシェア用テキスト（TrendsHelper#on_this_day_share_text、issue #1732）とは別のルールで、
# そちらには適用しない
class OnThisDayPostBuilder
  HEADER = 'ヴィジュアル系今日はなんの日？'
  TIME_ZONE = 'Asia/Tokyo'
  # 年を問わない日付（MM-DD）を Date にするときの年。2/29 も扱えるよううるう年にする
  MONTH_DAY_YEAR = 2000
  MONTH_DAY_PATTERN = %r{\A(\d{1,2})[-/](\d{1,2})\z}
  HASHTAG = '#vkdb'
  OTHERS_LINE = '・他'
  MAX_TRENDS = 5
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

  # OnThisDayPost を返す。載せる内容がない日（動向がなく、誕生日の行も載らない日）は nil
  def build
    selected = select_trends
    others = trends.size > selected.size
    birthday_line = build_birthday_line(selected, others)
    return nil if trends.empty? && birthday_line.nil?

    OnThisDayPost.new(date: @date, text: compose(selected, others, birthday_line), page_url: page_url)
  end

  # 当日の「今日はなんの日？」ページのURL（https）
  def page_url
    return @page_url if @page_url

    url_options = (Rails.application.config.action_mailer.default_url_options || {}).merge(protocol: 'https')
    @page_url = Rails.application.routes.url_helpers.birthday_date_url(month: @date.month, day: @date.day, **url_options)
  end

  private

  def trends
    @trends ||= Trend.published.on_month_day(@date.month, @date.day)
                     .select(:id, :date, :title, :units, :unit_phenomenon).to_a
  end

  def birthdays
    @birthdays ||= Person.kept.published.birthday_on(@date).order(name_kana: :asc).select(:id, :name).to_a
  end

  # 優先順位の高い候補から順に、280文字に収まるものを最大5件選ぶ（1バンド1件まで）
  def select_trends
    selected = []
    used_unit_keys = Set.new
    OnThisDayTrendRanker.new(trends, random: @random).ranked.each do |trend|
      break if selected.size >= MAX_TRENDS

      keys = OnThisDayTrendRanker.unit_keys(trend)
      next if keys.intersect?(used_unit_keys)

      candidate = selected + [trend]
      next unless XPostLength.fits?(compose(candidate, trends.size > candidate.size, nil))

      selected = candidate
      used_unit_keys.merge(keys)
    end
    selected
  end

  # 入るだけ人名を並べる（ランダムに選び、ヨミガナ順に並べる）。
  # 2人以上入らなければ nil（誕生日の人物が1人だけの日は、その1人が入れば載せる）
  def build_birthday_line(selected, others)
    names = []
    birthdays.each_with_index.to_a.shuffle(random: @random).each do |person, index|
      candidate = names + [[person.name, index]]
      line = birthday_line(candidate)
      names = candidate if XPostLength.fits?(compose(selected, others, line))
    end
    return nil if names.empty?
    return nil if names.size < 2 && names.size < birthdays.size

    birthday_line(names)
  end

  def birthday_line(names_with_index)
    names = names_with_index.sort_by(&:last).map(&:first)
    names << '他' if birthdays.size > names.size
    "誕生日: #{names.join('、')}"
  end

  def compose(selected, others, birthday_line)
    lines = ["#{HEADER}（#{@date.strftime('%m/%d')}）"]
    lines.concat(selected.sort_by(&:date).map { |trend| "・#{trend_line(trend)}" })
    lines << OTHERS_LINE if others
    lines << birthday_line if birthday_line
    lines << page_url
    lines << HASHTAG
    lines.join("\n")
  end

  def trend_line(trend)
    unit_names = (trend.units || []).filter_map do |unit_data|
      unit_data['name'].presence || related_units[unit_data['unit_id'].to_i]&.name
    end.join('、')
    title = trend.title_as_plain_text.sub(TITLE_TRAILING_PARENTHETICAL_PATTERN, '')
    ["#{trend.date.year}年", unit_names, title].compact_blank.join(' ')
  end

  def related_units
    @related_units ||= begin
      ids = trends.flat_map { |trend| OnThisDayTrendRanker.unit_ids(trend).to_a }.uniq
      Unit.kept.where(id: ids).select(:id, :name).index_by(&:id)
    end
  end
end

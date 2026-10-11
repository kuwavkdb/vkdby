# frozen_string_literal: true

require 'test_helper'

class OnThisDayPostBuilderTest < ActiveSupport::TestCase
  DATE = Date.new(2026, 5, 30)

  test '動向も誕生日もない日は空配列を返す' do
    assert_empty OnThisDayPostBuilder.new(DATE).build
  end

  test '出来事の投稿はヘッダー・動向・ページURL（#trends付き）・ハッシュタグの形式で、末尾の括弧書きを除く（issue #1742、#1753）' do
    unit = create_unit('黒夢')
    create_trend(unit, title: 'ワンマン（渋谷公会堂）', year: 1995)

    posts = OnThisDayPostBuilder.new(DATE).build

    assert_equal [:trends], posts.map(&:kind)
    post = posts.first
    assert_equal "#ヴィジュアル系今日は何の日？（5/30）\n・1995年 黒夢 ワンマン\nhttps://example.com/date/-/5/30#trends",
                 post.text
    assert_equal 'https://example.com/date/-/5/30#trends', post.page_url
    assert_equal "https://x.com/intent/post?text=#{ERB::Util.url_encode(post.text)}", post.intent_url
  end

  test '動向は280文字を超えても、すべて載せる（issue #1848）' do
    8.times { |i| create_trend(create_unit("U#{i}"), title: 'あ' * 40, year: 1990 + i) }

    post = trend_post

    assert_operator post.weighted_length, :>, XPostLength::MAX
    assert_equal(8, post.text.scan(/^・1/).size)
    assert_not_includes post.text, '・他'
  end

  test '動向は年の古い順に並べる' do
    [2001, 1995, 1999].each { |year| create_trend(create_unit("U#{year}"), title: '結成', year: year) }

    years = trend_post.text.scan(/・(\d{4})年/).flatten

    assert_equal %w[1995 1999 2001], years
  end

  test '同じバンドの動向もすべて載せる（issue #1848）' do
    unit = create_unit('黒夢')
    create_trend(unit, title: 'ライブ', year: 1991)
    create_trend(unit, title: '解散', phenomenon: :finish, year: 1999)

    lines = trend_post.text.split("\n")

    assert_equal ['・1991年 黒夢 ライブ', '・1999年 黒夢 解散'], lines[1..2]
  end

  test '非公開の動向は含めない' do
    create_trend(create_unit('黒夢'), title: '非公開の動向', year: 1995, active: false)

    assert_empty OnThisDayPostBuilder.new(DATE).build
  end

  test '月や日が不明な動向は含めない（issue #1848）' do
    create_trend(create_unit('黒夢'), title: '日が不明な動向', year: 1995, day_unknown: true)

    assert_empty OnThisDayPostBuilder.new(DATE).build
  end

  test '誕生日は別の投稿にし、誕生日用の見出しで1人1行ヨミガナ順に並べる（issue #1753）' do
    create_trend(create_unit('黒夢'), title: '結成', year: 1991)
    create_person('乙', 'おつ')
    create_person('甲', 'こう')

    posts = OnThisDayPostBuilder.new(DATE).build

    assert_equal %i[trends birthdays], posts.map(&:kind)
    assert_not_includes posts.first.text, '乙'
    assert_equal "今日（5/30）誕生日のヴィジュアル系アーティスト\n・乙\n・甲\nhttps://example.com/date/-/5/30\n#vkdb",
                 posts.last.text
  end

  test '誕生日の人物名の後にユニット名を付ける（issue #1753）' do
    create_person('清春', 'きよはる', old_history: '[[黒夢]]')
    create_person('人時', 'ひとき', old_history: '[[黒夢]] →')

    lines = birthday_post.text.split("\n")

    assert_includes lines, '・清春（黒夢）'
    assert_includes lines, '・人時（ex-黒夢）'
  end

  test '誕生日は280文字を超えても、全員をヨミガナ順に載せる（issue #1848）' do
    60.times { |i| create_person("名前#{format('%02d', i)}", "なまえ#{format('%02d', i)}") }

    post = birthday_post
    names = post.text.split("\n").select { |line| line.start_with?('・') }

    assert_operator post.weighted_length, :>, XPostLength::MAX
    assert_equal(60.times.map { |i| "・名前#{format('%02d', i)}" }, names)
  end

  test '動向がなく誕生日だけの日は誕生日の投稿だけを返す' do
    create_person('甲', 'こう')

    assert_equal [:birthdays], OnThisDayPostBuilder.new(DATE).build.map(&:kind)
  end

  test 'parse_month_dayはMM-DDとM/Dを受け付け、不正ならnil' do
    may30 = OnThisDayPostBuilder.parse_month_day('05-30')
    feb29 = OnThisDayPostBuilder.parse_month_day('2/29')
    assert_equal [5, 30], [may30.month, may30.day]
    assert_equal [2, 29], [feb29.month, feb29.day]
    assert_nil OnThisDayPostBuilder.parse_month_day('2026-05-30')
    assert_nil OnThisDayPostBuilder.parse_month_day('13-40')
  end

  private

  def trend_post
    OnThisDayPostBuilder.new(DATE).build.find { |post| post.kind == :trends }
  end

  def birthday_post
    OnThisDayPostBuilder.new(DATE).build.find { |post| post.kind == :birthdays }
  end

  def create_unit(name)
    @unit_seq = @unit_seq.to_i + 1
    Unit.create!(name: name, key: "on-this-day-unit-#{@unit_seq}", status: :active)
  end

  def create_trend(unit, title:, year:, phenomenon: :other, active: true, day_unknown: false)
    Trend.create!(title: title, date: Date.new(year, DATE.month, DATE.day), publish_start_at: Time.utc(2000, 1, 1),
                  unit_phenomenon: phenomenon, active: active, day_unknown: day_unknown,
                  units: [{ 'unit_id' => unit.id, 'name' => unit.name }])
  end

  def create_person(name, name_kana, old_history: nil)
    @person_seq = @person_seq.to_i + 1
    Person.create!(name: name, name_kana: name_kana, key: "on-this-day-person-#{@person_seq}", status: :active,
                   birthday: Date.new(1970, DATE.month, DATE.day), old_history: old_history)
  end
end

# frozen_string_literal: true

require 'test_helper'

class OnThisDayPostBuilderTest < ActiveSupport::TestCase
  DATE = Date.new(2026, 5, 30)

  test '動向も誕生日もない日はnilを返す' do
    assert_nil OnThisDayPostBuilder.new(DATE).build
  end

  test 'ヘッダー・動向・ページURL・ハッシュタグの形式で出力し、末尾の括弧書きを除く（issue #1742）' do
    unit = create_unit('黒夢')
    create_trend(unit, title: 'ワンマン（渋谷公会堂）', year: 1995)

    result = OnThisDayPostBuilder.new(DATE).build

    assert_equal "ヴィジュアル系今日はなんの日？（5/30）\n・1995年 黒夢 ワンマン\nhttps://example.com/date/-/5/30\n#vkdb", result.text
    assert_equal 'https://example.com/date/-/5/30', result.page_url
    assert_equal "https://x.com/intent/post?text=#{ERB::Util.url_encode(result.text)}", result.intent_url
  end

  test '動向は最大5件で、それ以上あれば「・他」を付ける' do
    7.times { |i| create_trend(create_unit("U#{i}"), title: '結成', year: 1990 + i) }

    lines = OnThisDayPostBuilder.new(DATE).build.text.split("\n")

    assert_equal(5, lines.count { |line| line.start_with?('・1') })
    assert_includes lines, '・他'
  end

  test '動向は年の古い順に並べる' do
    [2001, 1995, 1999].each { |year| create_trend(create_unit("U#{year}"), title: '結成', year: year) }

    years = OnThisDayPostBuilder.new(DATE).build.text.scan(/・(\d{4})年/).flatten

    assert_equal %w[1995 1999 2001], years
  end

  test '解散・活動休止を最優先し、その中でメジャー経験バンドを先にする' do
    major_units = Array.new(3) { |i| create_unit("M#{i}") }
    major_units.each { |unit| create_major_debut(unit) }
    indie_units = Array.new(5) { |i| create_unit("I#{i}") }

    create_trend(major_units[0], title: 'メジャー解散', phenomenon: :finish, year: 2000)
    create_trend(indie_units[0], title: 'インディ解散', phenomenon: :finish, year: 2001)
    create_trend(indie_units[1], title: 'インディ休止', phenomenon: :suspend, year: 2002)
    create_trend(major_units[1], title: 'メジャーライブ1', phenomenon: :live, year: 2003)
    create_trend(major_units[2], title: 'メジャーライブ2', phenomenon: :live, year: 2004)
    indie_units[2..].each_with_index do |unit, i|
      create_trend(unit, title: "インディライブ#{i}", phenomenon: :live, year: 2005 + i)
    end

    text = OnThisDayPostBuilder.new(DATE).build.text

    %w[メジャー解散 インディ解散 インディ休止 メジャーライブ1 メジャーライブ2].each do |title|
      assert_includes text, title
    end
    assert_not_includes text, 'インディライブ'
    assert_includes text, '・他'
  end

  test '同じバンドの動向は1件だけ選ぶ' do
    unit = create_unit('黒夢')
    create_trend(unit, title: '結成', year: 1991)
    create_trend(unit, title: '解散', phenomenon: :finish, year: 1999)

    lines = OnThisDayPostBuilder.new(DATE).build.text.split("\n")

    assert_includes lines, '・1999年 黒夢 解散'
    assert_not_includes lines, '・1991年 黒夢 結成'
    assert_includes lines, '・他'
  end

  test '非公開の動向は含めない' do
    create_trend(create_unit('黒夢'), title: '非公開の動向', year: 1995, active: false)

    assert_nil OnThisDayPostBuilder.new(DATE).build
  end

  test '280文字に収まらない動向は入れず、全体を280以内にする' do
    5.times { |i| create_trend(create_unit("U#{i}"), title: 'あ' * 40, year: 1990 + i) }

    result = OnThisDayPostBuilder.new(DATE).build

    assert_operator result.weighted_length, :<=, XPostLength::MAX
    assert_operator result.text.scan(/^・1/).size, :<, 5
    assert_includes result.text, '・他'
  end

  test '文字数に余裕があれば誕生日をヨミガナ順で加える' do
    create_trend(create_unit('黒夢'), title: '結成', year: 1991)
    create_person('乙', 'おつ')
    create_person('甲', 'こう')

    lines = OnThisDayPostBuilder.new(DATE).build.text.split("\n")

    assert_equal '誕生日: 乙、甲', lines[2]
  end

  test '誕生日が入りきらなければ入るだけ並べて「、他」を付ける' do
    60.times { |i| create_person("名前#{format('%02d', i)}", "なまえ#{format('%02d', i)}") }

    result = OnThisDayPostBuilder.new(DATE).build
    birthday_line = result.text.split("\n").find { |line| line.start_with?('誕生日: ') }

    assert_match(/、他\z/, birthday_line)
    assert_operator result.weighted_length, :<=, XPostLength::MAX
  end

  test '誕生日が2人以上入らなければ誕生日の行を省く' do
    create_trend(create_unit('黒夢'), title: '結成', year: 1991)
    create_person('あ' * 70, 'あ')
    create_person('い' * 70, 'い')

    text = OnThisDayPostBuilder.new(DATE).build.text

    assert_not_includes text, '誕生日:'
  end

  test '動向がなく、誕生日の行も載らない日はnilを返す' do
    create_person('あ' * 70, 'あ')
    create_person('い' * 70, 'い')

    assert_nil OnThisDayPostBuilder.new(DATE).build
  end

  test 'parse_month_dayはMM-DDとM/Dを受け付け、不正ならnil' do
    may30 = OnThisDayPostBuilder.parse_month_day('05-30')
    feb29 = OnThisDayPostBuilder.parse_month_day('2/29')
    assert_equal [5, 30], [may30.month, may30.day]
    assert_equal [2, 29], [feb29.month, feb29.day]
    assert_nil OnThisDayPostBuilder.parse_month_day('2026-05-30')
    assert_nil OnThisDayPostBuilder.parse_month_day('13-40')
  end

  test '動向がなく誕生日だけの日も出力する' do
    create_person('甲', 'こう')

    assert_equal "ヴィジュアル系今日はなんの日？（5/30）\n誕生日: 甲\nhttps://example.com/date/-/5/30\n#vkdb",
                 OnThisDayPostBuilder.new(DATE).build.text
  end

  private

  def create_unit(name)
    @unit_seq = @unit_seq.to_i + 1
    Unit.create!(name: name, key: "on-this-day-unit-#{@unit_seq}", status: :active)
  end

  def create_trend(unit, title:, year:, phenomenon: :other, active: true)
    Trend.create!(title: title, date: Date.new(year, DATE.month, DATE.day), publish_start_at: Time.utc(2000, 1, 1),
                  unit_phenomenon: phenomenon, active: active,
                  units: [{ 'unit_id' => unit.id, 'name' => unit.name }])
  end

  def create_major_debut(unit)
    Trend.create!(title: 'メジャーデビュー', date: Date.new(1995, 1, 1), publish_start_at: Time.utc(2000, 1, 1),
                  unit_phenomenon: :major_debut, units: [{ 'unit_id' => unit.id, 'name' => unit.name }])
  end

  def create_person(name, name_kana)
    Person.create!(name: name, name_kana: name_kana, key: "on-this-day-person-#{name_kana}", status: :active,
                   birthday: Date.new(1970, DATE.month, DATE.day))
  end
end

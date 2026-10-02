# frozen_string_literal: true

require 'test_helper'

class TrendsHelperTest < ActionView::TestCase
  include TrendsHelper

  test 'unit_name_badgeはユニット名をzincのバッジ<span>で返す' do
    html = unit_name_badge('名前だけのユニット')

    assert_dom_equal %(<span class="#{TrendsHelper::UNIT_NAME_BADGE_CLASS}">名前だけのユニット</span>), html
    assert_includes TrendsHelper::UNIT_NAME_BADGE_CLASS, 'bg-zinc-50'
    assert_not_includes TrendsHelper::UNIT_NAME_BADGE_CLASS, 'gray'
  end

  test 'unit_name_badgeはユニット名をエスケープする' do
    html = unit_name_badge('<script>alert(1)</script>')

    assert_includes html, '&lt;script&gt;alert(1)&lt;/script&gt;'
    assert_not_includes html, '<script>'
  end

  test 'twitter_embedはXのoEmbed HTMLを保ったままウィジェットのscriptを付ける' do
    quote = '<blockquote class="twitter-tweet" data-lang="ja"><p lang="ja" dir="ltr">お知らせ<br>本文</p>' \
            '&mdash; バンド (@band) <a href="https://twitter.com/band/status/1">August 14, 2026</a></blockquote>'

    html = twitter_embed('https://x.com/band/status/1', quote)

    assert_includes html, '<blockquote class="twitter-tweet" data-lang="ja"><p lang="ja" dir="ltr">お知らせ<br>本文</p>'
    assert_includes html, '<a href="https://twitter.com/band/status/1">August 14, 2026</a>'
    assert_includes html, '<script async="async" src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>'
  end

  test 'twitter_embedはquoteに含まれるscriptやjavascript:のリンク・イベント属性を取り除く' do
    quote = '<blockquote class="twitter-tweet"><p onclick="alert(1)">本文</p><script>alert(2)</script>' \
            '<a href="javascript:alert(3)">リンク</a><img src="x" onerror="alert(4)"></blockquote>'

    html = twitter_embed('https://x.com/band/status/1', quote)

    # <script> はタグだけが取り除かれ、中身は実行されない文字として残る
    assert_includes html, '<p>本文</p>alert(2)<a>リンク</a>'
    %w[onclick onerror javascript: <img].each { |fragment| assert_not_includes html, fragment }
    assert_equal 1, html.scan('<script').size
    assert_includes html, '<script async="async" src="https://platform.twitter.com/widgets.js"'
  end

  test 'on_this_day_share_textは動向から3件を選び、末尾の括弧書きを除き、4件以上なら「他」を付ける（issue #1732）' do
    trends = [
      Trend.new(title: 'ワンマン (渋谷公会堂)', date: Date.new(1995, 5, 30), units: [{ 'name' => 'ユニットA' }]),
      Trend.new(title: '解散発表（公式サイト）', date: Date.new(2000, 5, 30), units: [{ 'name' => 'ユニットB' }]),
      Trend.new(title: '結成', date: Date.new(2005, 5, 30)),
      Trend.new(title: '再結成', date: Date.new(2010, 5, 30), units: [{ 'name' => 'ユニットC' }])
    ]
    birthdays = [Person.new(name: '誕生日の人')]

    lines = on_this_day_share_text(trends, month: 5, day: 30, birthdays: birthdays).split("\n")

    assert_equal 'ヴィジュアル系今日はなんの日？', lines.first
    candidates = ['・1995年 ユニットA ワンマン', '・2000年 ユニットB 解散発表', '・2005年 結成', '・2010年 ユニットC 再結成']
    lines[1..3].each { |line| assert_includes candidates, line }
    assert_equal ['・他', birthday_date_url(month: 5, day: 30), '#vkdb'], lines[4..]
  end

  test 'on_this_day_share_textは動向がちょうど3件なら「他」も誕生日も付けない' do
    trends = (1..3).map { |i| Trend.new(title: "動向#{i}", date: Date.new(2000 + i, 5, 30)) }
    birthdays = [Person.new(name: '誕生日の人')]

    text = on_this_day_share_text(trends, month: 5, day: 30, birthdays: birthdays)

    assert_equal "ヴィジュアル系今日はなんの日？\n・2001年 動向1\n・2002年 動向2\n・2003年 動向3\n" \
                 "#{birthday_date_url(month: 5, day: 30)}\n#vkdb", text
  end

  test 'on_this_day_share_textは動向が3件未満なら誕生日を加える（issue #1732）' do
    trends = [Trend.new(title: '結成', date: Date.new(2005, 5, 30))]
    birthdays = [Person.new(name: '甲'), Person.new(name: '乙')]

    text = on_this_day_share_text(trends, month: 5, day: 30, birthdays: birthdays)

    assert_equal "ヴィジュアル系今日はなんの日？\n・2005年 結成\n誕生日: 甲、乙\n" \
                 "#{birthday_date_url(month: 5, day: 30)}\n#vkdb", text
  end

  test 'on_this_day_share_textは誕生日が4件以上なら3件をランダムに選び「他」を付ける' do
    names = %w[甲 乙 丙 丁]
    birthdays = names.map { |name| Person.new(name: name) }

    lines = on_this_day_share_text([], month: 5, day: 30, birthdays: birthdays).split("\n")

    birthday_line = lines[1]
    assert_match(/\A誕生日: .+、他\z/, birthday_line)
    picked = birthday_line.delete_prefix('誕生日: ').split('、')[0..-2]
    assert_equal 3, picked.size
    assert_equal picked.sort_by { |name| names.index(name) }, picked
  end

  test 'on_this_day_share_textは解散・活動休止の動向を優先し、足りない分を他の動向から補う（issue #1732）' do
    trends = [
      Trend.new(title: 'ライブ1', date: Date.new(1990, 5, 30), unit_phenomenon: :live),
      Trend.new(title: '解散', date: Date.new(1995, 5, 30), unit_phenomenon: :finish),
      Trend.new(title: 'ライブ2', date: Date.new(2000, 5, 30), unit_phenomenon: :live),
      Trend.new(title: '活動休止', date: Date.new(2005, 5, 30), unit_phenomenon: :suspend),
      Trend.new(title: 'ライブ3', date: Date.new(2010, 5, 30), unit_phenomenon: :live)
    ]

    lines = on_this_day_share_text(trends, month: 5, day: 30).split("\n")

    assert_includes lines, '・1995年 解散'
    assert_includes lines, '・2005年 活動休止'
    assert_equal 3, lines.count { |l| l.match?(/\A・\d{4}年/) }
    assert_includes lines, '・他'
  end
end

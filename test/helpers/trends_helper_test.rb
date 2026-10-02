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

  test 'on_this_day_share_textは動向から3件を選び、末尾の括弧書きを除いて出力する（issue #1732）' do
    trends = [
      Trend.new(title: 'ワンマン (渋谷公会堂)', date: Date.new(1995, 5, 30), units: [{ 'name' => 'ユニットA' }]),
      Trend.new(title: '解散発表（公式サイト）', date: Date.new(2000, 5, 30), units: [{ 'name' => 'ユニットB' }]),
      Trend.new(title: '結成', date: Date.new(2005, 5, 30)),
      Trend.new(title: '再結成', date: Date.new(2010, 5, 30), units: [{ 'name' => 'ユニットC' }])
    ]

    lines = on_this_day_share_text(trends, month: 5, day: 30).split("\n")

    assert_equal 'ヴィジュアル系今日はなんの日？', lines.first
    assert_equal 3, lines.count { |l| l.start_with?('・') }
    assert_equal birthday_date_url(month: 5, day: 30), lines[-2]
    assert_equal '#vkdb', lines.last
    candidates = ['・1995年 ユニットA ワンマン', '・2000年 ユニットB 解散発表', '・2005年 結成', '・2010年 ユニットC 再結成']
    lines[1..3].each { |line| assert_includes candidates, line }
  end

  test 'on_this_day_share_textは動向が3件未満ならある分だけ出力する' do
    trends = [Trend.new(title: '結成', date: Date.new(2005, 5, 30))]

    text = on_this_day_share_text(trends, month: 5, day: 30)

    assert_equal "ヴィジュアル系今日はなんの日？\n・2005年 結成\n#{birthday_date_url(month: 5, day: 30)}\n#vkdb", text
  end
end

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

  test 'trend_date_pathは日付の分かり方に応じて日付・月別・年別ページを返す（issue #1917）' do
    date = Date.new(2020, 12, 1)

    assert_equal daily_path(year: 2020, month: 12, day: 1), trend_date_path(Trend.new(date: date))
    assert_equal monthly_path(year: 2020, month: 12), trend_date_path(Trend.new(date: date, day_unknown: true))
    assert_equal yearly_path(year: 2020),
                 trend_date_path(Trend.new(date: Date.new(2020, 1, 1), day_unknown: true, month_unknown: true))
  end
end

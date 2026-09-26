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

    assert_not_includes html, 'alert'
    assert_not_includes html, '<img'
    assert_equal 1, html.scan('<script').size
  end
end

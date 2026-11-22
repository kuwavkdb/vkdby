# frozen_string_literal: true

require 'test_helper'

class TrendsHelperTest < ActionView::TestCase
  include TrendsHelper
  include TrendLeadBadgesHelper

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

  test 'trend_unpublished_labelは公開予約中なら公開開始日時を日本時間で返す' do
    trend = Trend.new(active: true, publish_start_at: Time.utc(2099, 1, 2, 3, 4, 5))

    assert_equal '2099/01/02 12:04:05 公開', trend_unpublished_label(trend)
  end

  test 'trend_unpublished_labelは公開するにチェックがなければ非公開の文言を返す' do
    trend = Trend.new(active: false, publish_start_at: Time.utc(2099, 1, 2, 3, 4, 5))

    assert_equal '非公開', trend_unpublished_label(trend)
    assert_equal '非公開（管理者のみ閲覧可）', trend_unpublished_label(trend, unpublished_text: '非公開（管理者のみ閲覧可）')
  end

  test 'trend_news_release_labelはニュースリリースのラベルを返す' do
    assert_equal 'ニュースリリース', Nokogiri::HTML.fragment(trend_news_release_label).text
  end

  # issue #2092: 一覧の件名の前のバッジ
  def lead_badge_trend(**attrs)
    Trend.new(title: 'T', date: Date.current, publish_start_at: Time.current, **attrs)
  end

  test 'trend_lead_badgesは通常の動向でユニット名を出し、個人名は出さない' do
    unit = Unit.new(id: 1, key: 'lead-unit', name: 'ユニットA')
    trend = lead_badge_trend(unit_phenomenon: :live, units: [{ 'unit_id' => 1, 'name' => 'ユニットA' }],
                             people: [{ 'person_id' => 2, 'name' => '個人A' }])

    html = trend_lead_badges(trend, related_units: { 1 => unit }, related_people: {})

    assert_includes html, %(href="/lead-unit")
    assert_not_includes html, '個人A'
  end

  test 'trend_lead_badgesは個人名を件名前に優先表示する動向でユニット名の代わりに個人名を出す' do
    person = Person.new(id: 2, key: 'lead-person', name: '個人A')
    trend = lead_badge_trend(unit_phenomenon: :live, person_name_in_title: true,
                             units: [{ 'unit_id' => 1, 'name' => 'ユニットA' }],
                             people: [{ 'person_id' => 2, 'name' => '個人A' }, { 'person_id' => nil, 'name' => '未登録の個人' }])

    html = trend_lead_badges(trend, related_units: {}, related_people: { 2 => person })

    assert_includes html, %(href="/lead-person")
    assert_includes html, '未登録の個人'
    assert_not_includes html, 'ユニットA'
  end

  test 'trend_lead_badgesはcurrent_unit_nameなら今のユニット名を出す' do
    unit = Unit.new(id: 1, key: 'lead-unit', name: '今の名前')
    trend = lead_badge_trend(unit_phenomenon: :live, units: [{ 'unit_id' => 1, 'name' => '登録時の名前' }])

    assert_includes trend_lead_badges(trend, related_units: { 1 => unit }, current_unit_name: true), '今の名前'
    assert_includes trend_lead_badges(trend, related_units: { 1 => unit }), '登録時の名前'
  end
end

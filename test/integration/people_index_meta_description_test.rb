# frozen_string_literal: true

require 'test_helper'

# 個人索引（/people）のmeta description（issue #1959）
class PeopleIndexMetaDescriptionTest < ActionDispatch::IntegrationTest
  setup do
    @era_group = IndexGroup.create!(name: '年代', people_filter_order: 1)
    @era_tag = TagIndex.create!(name: '年代/2000年代', index_group: @era_group, order_in_group: 1)
    @total = Person.for_index.count + 3
    alpha = Person.create!(name: 'Meta People Alpha', key: 'meta-people-alpha', status: :active,
                           parts: %w[vocal], hometown: '東京都', blood: 'A')
    Person.create!(name: 'Meta People Beta', key: 'meta-people-beta', status: :active, parts: %w[vocal])
    Person.create!(name: 'Other Gamma', key: 'meta-people-gamma', status: :retirement, parts: %w[guitar])
    TagIndexItem.create!(tag_index: @era_tag, indexable: alpha)
  end

  def meta_description
    css_select('meta[name="description"]').first['content']
  end

  def total = @total.to_fs(:delimited)

  test '絞り込みなしは登録数を書き、見出しの下にも同じ文を表示する' do
    get people_path

    assert_equal "ヴィジュアル系バンドマン・アーティストの索引。登録数は#{total}人。" \
                 '名前やよみがなで探せるほか、パート・出身地・タグなどで絞り込めます。', meta_description
    assert_select 'header p', text: meta_description
    assert_no_match(/records/, css_select('header h1').text)
  end

  test '検索語だけで絞り込んだときは検索語と「絞り込み後/全体」の件数を書き、noindex にする' do
    get people_path(q: 'Meta People')

    assert_equal "「Meta People」で探したヴィジュアル系バンドマン・アーティストの一覧（2/#{total}件）。", meta_description
    assert_select 'meta[name="robots"][content="noindex, follow"]', count: 1
  end

  test '個人の項目とタグは、パート→出身地→状況→血液型→タグの順に書き、検索語を最後に加える' do
    get people_path(q: 'Alpha', part: 'vocal', hometown: '東京都', status: 'active', blood: 'A',
                    tag_ids: { @era_group.id.to_s => @era_tag.id.to_s })

    assert_equal '「ボーカル」「東京都」「活動中」「A型」「2000年代」のヴィジュアル系バンドマン・アーティストのうち、' \
                 "「Alpha」で探した一覧（1/#{total}件）。", meta_description
  end

  test '検索語の無い絞り込みは noindex にしない' do
    get people_path(part: 'vocal')

    assert_equal "「ボーカル」のヴィジュアル系バンドマン・アーティストの一覧（2/#{total}件）。", meta_description
    assert_select 'meta[name="robots"]', count: 0
  end
end

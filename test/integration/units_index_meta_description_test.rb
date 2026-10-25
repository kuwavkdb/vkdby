# frozen_string_literal: true

require 'test_helper'

# バンド索引（/units）のmeta descriptionと、旧サイトの索引ページ（/-）の転送（issue #1957）
class UnitsIndexMetaDescriptionTest < ActionDispatch::IntegrationTest
  TAIL = '各バンドの歴史やメンバーの経歴、音源等を掲載。'

  setup do
    @status_group = IndexGroup.create!(name: '状況', units_filter_order: 1)
    @era_group = IndexGroup.create!(name: '年代', units_filter_order: 2)
    @active_tag = TagIndex.create!(name: '状況/活動中', index_group: @status_group, order_in_group: 1)
    @era_tag = TagIndex.create!(name: '年代/2000年代', index_group: @era_group, order_in_group: 1)
    @total = Unit.for_index.count + 3
    alpha = Unit.create!(name: 'Meta Index Alpha', key: 'meta-index-alpha', status: :active)
    beta = Unit.create!(name: 'Meta Index Beta', key: 'meta-index-beta', status: :active)
    Unit.create!(name: 'Other Gamma', key: 'meta-index-gamma', status: :active)
    [[alpha, @active_tag], [alpha, @era_tag], [beta, @active_tag]].each do |unit, tag|
      TagIndexItem.create!(tag_index: tag, indexable: unit)
    end
  end

  def meta_description
    css_select('meta[name="description"]').first['content']
  end

  test '/- はバンド索引に転送する' do
    get '/-'

    assert_response :moved_permanently
    assert_redirected_to '/units'
  end

  test '絞り込みなしは登録数を書く' do
    get units_path

    assert_equal "ヴィジュアル系バンド・アーティストの索引。登録数は#{@total.to_fs(:delimited)}組。" \
                 "名前やよみがなで探せるほか、タグで絞り込めます。#{TAIL}", meta_description
  end

  test '検索語だけで絞り込んだときは検索語と「絞り込み後/全体」の件数を書く' do
    get units_path(q: 'Meta Index')

    assert_equal "「Meta Index」で探したヴィジュアル系バンド・アーティストの一覧（2/#{@total.to_fs(:delimited)}件）。#{TAIL}",
                 meta_description
  end

  test 'タグだけで絞り込んだときは、タグを絞り込みグループの順に書く' do
    get units_path(tag_ids: { @era_group.id.to_s => @era_tag.id.to_s, @status_group.id.to_s => @active_tag.id.to_s })

    assert_equal "「活動中」「2000年代」のヴィジュアル系バンド・アーティストの一覧（1/#{@total.to_fs(:delimited)}件）。#{TAIL}",
                 meta_description
  end

  test 'タグと検索語で絞り込んだときは、タグを先に書いて検索語を加える' do
    get units_path(q: 'Beta', tag_ids: { @status_group.id.to_s => @active_tag.id.to_s })

    assert_equal '「活動中」のヴィジュアル系バンド・アーティストのうち、「Beta」で探した一覧' \
                 "（1/#{@total.to_fs(:delimited)}件）。#{TAIL}", meta_description
  end
end

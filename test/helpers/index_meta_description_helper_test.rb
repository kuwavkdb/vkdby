# frozen_string_literal: true

require 'test_helper'

class IndexMetaDescriptionHelperTest < ActionView::TestCase
  test 'units_index_meta_descriptionは2ページ目以降にページ番号を添える（issue #1957）' do
    assert_includes units_index_meta_description(total: 3456, page: 2), '登録数は3,456組（2ページ目）。'
    assert_includes units_index_meta_description(total: 3456, filtered_count: 120, query: 'Meta', page: 3),
                    '「Meta」で探したヴィジュアル系バンドの一覧（120/3,456件・3ページ目）。'
  end

  test 'units_index_meta_descriptionは長い検索語を切る（issue #1957）' do
    description = units_index_meta_description(total: 10, filtered_count: 0, query: 'あ' * 50)

    assert_includes description, "「#{'あ' * 27}...」で探した"
  end

  test 'people_index_filter_namesはパート→出身地→状況→血液型の順に表示名を返す（issue #1959）' do
    assert_equal %w[ボーカル 東京都 引退 B型],
                 people_index_filter_names(part: 'vocal', hometown: '東京都', status: 'retirement', blood: 'B')
    assert_empty people_index_filter_names
  end

  test 'people_index_filter_namesは状況・血液型の不明を書き分ける（issue #1959）' do
    assert_equal %w[状況不明 血液型不明], people_index_filter_names(status: 'unknown', blood: 'Unknown')
  end

  test 'people_index_meta_descriptionは2ページ目以降にページ番号を添える（issue #1959）' do
    assert_includes people_index_meta_description(total: 12_345, page: 2), '登録数は12,345人（2ページ目）。'
  end

  test 'index_selected_tag_namesは絞り込みグループに無いタグもidから引いて後ろに並べる（issue #1959）' do
    group = IndexGroup.create!(name: '年代', people_filter_order: 1)
    era = TagIndex.create!(name: '年代/2000年代', index_group: group, order_in_group: 1)
    other = TagIndex.create!(name: 'パート/ボーカル')

    names = index_selected_tag_names(IndexGroup.where(id: group.id).includes(:tag_indices),
                                     { '999' => other.id.to_s, group.id.to_s => era.id.to_s })

    assert_equal %w[2000年代 ボーカル], names
  end
end

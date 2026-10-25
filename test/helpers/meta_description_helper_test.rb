# frozen_string_literal: true

require 'test_helper'

class MetaDescriptionHelperTest < ActionView::TestCase
  test 'PART_NAMESはPerson::AVAILABLE_PARTSのパートをすべて持つ（issue #1938）' do
    assert_equal Person::AVAILABLE_PARTS.sort, MetaDescriptionHelper::PART_NAMES.keys.sort
  end

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
    assert_equal %w[血液型不明], people_index_filter_names(blood: 'Unknown')
    assert_empty people_index_filter_names
  end

  test 'people_index_meta_descriptionは2ページ目以降にページ番号を添える（issue #1959）' do
    assert_includes people_index_meta_description(total: 12_345, page: 2), '登録数は12,345人（2ページ目）。'
  end
end

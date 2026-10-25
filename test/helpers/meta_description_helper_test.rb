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
end

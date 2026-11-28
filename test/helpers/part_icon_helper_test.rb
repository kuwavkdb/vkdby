# frozen_string_literal: true

require 'test_helper'

# issue #2144: 管理画面のパートの選択肢に付けるアイコン
class PartIconHelperTest < ActionView::TestCase
  test '個人・メンバーのすべてのパートにアイコンがある' do
    parts = (Person::AVAILABLE_PARTS + SnapshotPerson.parts.keys).uniq

    parts.each do |part|
      assert_not_nil part_icon(part), "#{part} のアイコンがない"
    end
  end

  test 'アイコンは飾りとして読み上げの対象から外す' do
    render html: part_icon('guitar')

    assert_select 'svg[aria-hidden="true"][viewBox="0 0 24 24"]', count: 1
  end

  test 'ギターとベースは別の見た目にする' do
    assert_not_equal part_icon('guitar'), part_icon('bass')
  end

  test 'シンボルでも指定できる' do
    assert_equal part_icon('vocal'), part_icon(:vocal)
  end

  test 'アイコンの無いパートは nil を返す' do
    assert_nil part_icon('theremin')
  end

  test '指定した class を付ける' do
    render html: part_icon('drums', css_class: 'h-4 w-4')

    assert_select 'svg.h-4.w-4'
  end
end

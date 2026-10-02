# frozen_string_literal: true

require 'test_helper'

class KanaHelperTest < ActionView::TestCase
  test 'show_kana?は名前とヨミガナが異なる場合にtrueを返す' do
    assert show_kana?('黒夢', 'クロユメ')
  end

  test 'show_kana?は名前とヨミガナが一致する場合にfalseを返す（issue #1730）' do
    assert_not show_kana?('クロユメ', 'クロユメ')
    assert_not show_kana?('クロユメ', ' クロユメ ')
  end

  test 'show_kana?はヨミガナが空の場合にfalseを返す' do
    assert_not show_kana?('黒夢', nil)
    assert_not show_kana?('黒夢', '')
  end

  test 'name_with_kanaは名前とヨミガナが異なる場合に括弧書きでヨミガナを付ける' do
    assert_equal '黒夢（クロユメ）', name_with_kana('黒夢', 'クロユメ')
  end

  test 'name_with_kanaは名前とヨミガナが一致する場合は名前のみを返す（issue #1730）' do
    assert_equal 'クロユメ', name_with_kana('クロユメ', 'クロユメ')
    assert_equal '黒夢', name_with_kana('黒夢', nil)
  end
end

# frozen_string_literal: true

require 'test_helper'

class XPostLengthTest < ActiveSupport::TestCase
  test '半角英数字は1、日本語は2として数える（issue #1742）' do
    assert_equal 4, XPostLength.count('#vkd')
    assert_equal 6, XPostLength.count('解散。')
    assert_equal 7, XPostLength.count("ab\n解散")
  end

  test 'URLは長さによらず23として数える' do
    assert_equal 23, XPostLength.count('https://www.vkdb.jp/date/-/5/30')
    assert_equal 23 + 1 + 5, XPostLength.count("https://example.com/very/long/path/to/page\n#vkdb")
  end

  test 'fits?は280以下ならtrue' do
    assert XPostLength.fits?('あ' * 140)
    assert_not XPostLength.fits?("#{'あ' * 140}a")
  end
end

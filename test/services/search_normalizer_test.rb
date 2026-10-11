# frozen_string_literal: true

require 'test_helper'

# issue #1842: 検索の表記ゆれの吸収
class SearchNormalizerTest < ActiveSupport::TestCase
  test 'normalize folds width, case, hiragana, vu, long vowels, spaces and symbols' do
    assert_equal 'direngrey', SearchNormalizer.normalize('DIR EN GREY')
    assert_equal 'ディルアングレイ', SearchNormalizer.normalize('でぃるあんぐれい')
    assert_equal 'ガゼット', SearchNormalizer.normalize('ｶﾞｾﾞｯﾄ')
    assert_equal 'abc123', SearchNormalizer.normalize('ＡＢＣ１２３')
    assert_equal 'lasadies', SearchNormalizer.normalize("La:Sadie's")
    assert_equal SearchNormalizer.normalize('ビドール'), SearchNormalizer.normalize('ヴィドール')
    assert_equal SearchNormalizer.normalize('ナイトメア'), SearchNormalizer.normalize('ナイトメアー')
  end

  test 'normalize returns an empty string for a symbol-only name' do
    assert_equal '', SearchNormalizer.normalize('†')
  end

  test 'join normalizes each name and separates them with a space' do
    assert_equal 'direngrey ディルアングレイ', SearchNormalizer.join(['DIR EN GREY', 'ディルアングレイ', nil, '†', 'dir en grey'])
  end

  test 'words splits the query on half- and full-width spaces' do
    assert_equal %w[京 ディル], SearchNormalizer.words(" 京　ディル ")
  end
end

# frozen_string_literal: true

require 'test_helper'

# issue #2042: ひらがなだけの検索語は、カタカナにした語もあわせて返す
class SearchQueryTest < ActiveSupport::TestCase
  test 'variants adds a katakana variant when the query is all hiragana' do
    assert_equal %w[でぃる ディル], SearchQuery.variants('でぃる')
  end

  test 'variants allows the long vowel mark and spaces in a hiragana query' do
    assert_equal ['ないとめあー ばんど', 'ナイトメアー バンド'], SearchQuery.variants('ないとめあー ばんど')
  end

  test 'variants converts small kana and vu' do
    assert_equal %w[ゔぃどーる ヴィドール], SearchQuery.variants('ゔぃどーる')
  end

  test 'variants returns only the query when it contains anything other than hiragana' do
    assert_equal ['ディル'], SearchQuery.variants('ディル')
    assert_equal ['でぃるDIR'], SearchQuery.variants('でぃるDIR')
    assert_equal ['京でぃる'], SearchQuery.variants('京でぃる')
  end

  test 'variants returns only the query when it has no hiragana' do
    assert_equal ['ー'], SearchQuery.variants('ー')
    assert_equal [''], SearchQuery.variants('')
  end
end

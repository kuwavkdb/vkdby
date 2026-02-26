# frozen_string_literal: true

require 'test_helper'

class ItemConverterTest < ActiveSupport::TestCase
  # extract_wiki_links のテスト（private メソッドなので send で呼び出す）
  def extract_wiki_links(text)
    ItemConverter.new(nil).send(:extract_wiki_links, text)
  end

  test '[[名前]] 形式は name のみ設定される' do
    result = extract_wiki_links('[[アーティスト名]]')
    assert_equal 1, result.size
    assert_equal 'アーティスト名', result.first['name']
    assert_nil result.first['alias']
  end

  test '[[表示名|名前]] 形式は name と alias が設定される' do
    result = extract_wiki_links('[[表示名|正式名]]')
    assert_equal 1, result.size
    assert_equal '正式名', result.first['name']
    assert_equal '表示名', result.first['alias']
  end

  test '(アーティスト) などの接尾辞が除去される' do
    result = extract_wiki_links('[[アーティスト名(アーティスト)]]')
    assert_equal 'アーティスト名', result.first['name']
    assert_nil result.first['alias']
  end

  test '[[表示名(suffix)|名前]] 形式は alias から suffix が除去される' do
    result = extract_wiki_links('[[表示名(アーティスト)|正式名]]')
    assert_equal '正式名', result.first['name']
    assert_equal '表示名', result.first['alias']
  end

  test '複数の wiki リンクが解析される' do
    result = extract_wiki_links('[[表示A|名前A]] と [[名前B]]')
    assert_equal 2, result.size

    assert_equal '名前A', result[0]['name']
    assert_equal '表示A', result[0]['alias']

    assert_equal '名前B', result[1]['name']
    assert_nil result[1]['alias']
  end
end

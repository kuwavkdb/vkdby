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

  # encode_euc_jp のテスト
  def encode_euc_jp(text)
    ItemConverter.new(nil).send(:encode_euc_jp, text)
  end

  test 'ASCII のみのテキストは CGI.escape でエンコードされる' do
    assert_equal 'Dir+en+grey', encode_euc_jp('Dir en grey')
    assert_equal 'Plastic+Tree', encode_euc_jp('Plastic Tree')
    assert_equal 'the+GazettE', encode_euc_jp('the GazettE')
  end

  test 'スペースのない ASCII テキストはそのまま返る' do
    assert_equal 'lynch.', encode_euc_jp('lynch.')
    assert_equal 'MUCC', encode_euc_jp('MUCC')
  end

  test '日本語テキストは EUC-JP でエンコードされる' do
    # ディルアングレイ (EUC-JP) = %A5%C7%A5%A3%A5%EB%A5%A2%A5%F3%A5%B0%A5%EC%A5%A4
    assert_equal '%A5%C7%A5%A3%A5%EB%A5%A2%A5%F3%A5%B0%A5%EC%A5%A4', encode_euc_jp('ディルアングレイ')
  end

  test '空文字は空文字を返す' do
    assert_equal '', encode_euc_jp('')
    assert_equal '', encode_euc_jp(nil)
  end
end

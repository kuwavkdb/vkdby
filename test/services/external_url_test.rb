# frozen_string_literal: true

require 'test_helper'

class ExternalUrlTest < ActiveSupport::TestCase
  test 'http / https の絶対URLはそのまま返す' do
    assert_equal 'https://shop.example.com/items/1?ref=a', ExternalUrl.sanitize('https://shop.example.com/items/1?ref=a')
    assert_equal 'http://shop.example.com/', ExternalUrl.sanitize('http://shop.example.com/')
  end

  test 'ASCII以外の文字はパーセントエンコードして返す' do
    assert_equal 'https://shop.example.com/%E5%95%86%E5%93%81/1?q=%E3%81%82',
                 ExternalUrl.sanitize('https://shop.example.com/商品/1?q=あ')
  end

  test 'http / https 以外のスキームは拒否する' do
    assert_nil ExternalUrl.sanitize('javascript:alert(1)')
    assert_nil ExternalUrl.sanitize('JavaScript:alert(1)')
    assert_nil ExternalUrl.sanitize('data:text/html,<script>alert(1)</script>')
    assert_nil ExternalUrl.sanitize('ftp://example.com/')
  end

  test '相対URL・プロトコル相対URL・ホストの無いURLは拒否する' do
    assert_nil ExternalUrl.sanitize('/items/1')
    assert_nil ExternalUrl.sanitize('//evil.example/')
    assert_nil ExternalUrl.sanitize('https:///path')
  end

  test 'ユーザー情報付きのURLは拒否する' do
    assert_nil ExternalUrl.sanitize('https://shop.example.com@evil.example/')
  end

  test '空白・制御文字を含むURLは拒否する' do
    assert_nil ExternalUrl.sanitize("https://shop.example.com/\nSet-Cookie: a=b")
    assert_nil ExternalUrl.sanitize(" javascript:alert(1)")
    assert_nil ExternalUrl.sanitize("java\tscript:alert(1)")
    assert_nil ExternalUrl.sanitize('https://shop.example.com/a b')
  end

  test 'nil・空文字・解釈できないURLは nil' do
    assert_nil ExternalUrl.sanitize(nil)
    assert_nil ExternalUrl.sanitize('')
    assert_nil ExternalUrl.sanitize('https://exa mple.com')
    assert_nil ExternalUrl.sanitize('http://[invalid')
  end

  test 'display_host は先頭の www. を省いたホスト名を返す' do
    assert_equal 'example-shop.jp', ExternalUrl.display_host('https://www.example-shop.jp/items/1')
    assert_nil ExternalUrl.display_host('javascript:alert(1)')
  end
end

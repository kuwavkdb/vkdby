# frozen_string_literal: true

require 'test_helper'

class WikiLinkHelperTest < ActionView::TestCase
  include WikiLinkHelper

  # parse_wiki_lines は private なため format_wiki_content 経由でテスト

  test 'Twitter URLを含むbqブロックがtweet embedとして出力される' do
    wiki_text = <<~WIKI
      {{bq https://twitter.com/rui_0726_dv/status/516968877503180801
      <blockquote class="twitter-tweet" lang="ja"><p>バンド名はDevelop One's Faculties</p>&#8212; rui (@rui_0726_dv) <a href="https://twitter.com/rui_0726_dv/status/516968877503180801">2014, 9月 30</a></blockquote>
      <script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>
      }}
    WIKI

    result = format_wiki_content(wiki_text)

    # <blockquote class="twitter-tweet"> が出力に含まれること
    assert_match(/twitter-tweet/, result)
    # Twitter widget scriptが付加されること
    assert_match(%r{platform\.twitter\.com/widgets\.js}, result)
  end

  test 'Twitter URLのないbqブロックは通常のblockquoteとして出力される' do
    wiki_text = <<~WIKI
      {{bq
      これは通常の引用文です。
      }}
    WIKI

    result = format_wiki_content(wiki_text)

    # 通常の<blockquote>が出力されること
    assert_match(/<blockquote/, result)
    # tweet embed用のscriptは付加されないこと
    assert_no_match(/platform\.twitter\.com/, result)
  end

  test 'x.com URLを含むbqブロックもtweet embedとして出力される' do
    wiki_text = <<~WIKI
      {{bq https://x.com/example/status/123456789
      <blockquote class="twitter-tweet" lang="ja"><p>テスト</p></blockquote>
      }}
    WIKI

    result = format_wiki_content(wiki_text)

    assert_match(/twitter-tweet/, result)
    assert_match(%r{platform\.twitter\.com/widgets\.js}, result)
  end
end

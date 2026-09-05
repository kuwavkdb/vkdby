# frozen_string_literal: true

require 'test_helper'

class WikiLinkHelperTest < ActionView::TestCase
  include WikiLinkHelper
  include ApplicationHelper # parse_wiki_linksの外部URL自動リンク処理がexternal_url?（ApplicationHelper）に依存するため

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

  test 'youtube2プラグインにIDを指定した場合はそのままembedされる' do
    result = format_wiki_content('{{youtube2 dQw4w9WgXcQ}}')

    assert_match(%r{youtube\.com/embed/dQw4w9WgXcQ}, result)
  end

  test 'youtube2プラグインにyoutube.com URLを指定した場合はIDを抽出してembedされる' do
    result = format_wiki_content('{{youtube2 https://www.youtube.com/watch?v=dQw4w9WgXcQ}}')

    assert_match(%r{youtube\.com/embed/dQw4w9WgXcQ}, result)
  end

  test 'youtube2プラグインにyoutu.be URLを指定した場合はIDを抽出してembedされる' do
    result = format_wiki_content('{{youtube2 https://youtu.be/dQw4w9WgXcQ}}')

    assert_match(%r{youtube\.com/embed/dQw4w9WgXcQ}, result)
  end

  test '本文中に単独で書かれたYouTube watch URLはプラグイン記法なしでembedされる' do
    result = format_wiki_content("動画はこちら\nhttps://www.youtube.com/watch?v=dQw4w9WgXcQ\n")

    assert_match(%r{youtube\.com/embed/dQw4w9WgXcQ}, result)
  end

  test '本文中に単独で書かれたyoutu.be URLはプラグイン記法なしでembedされる' do
    result = format_wiki_content('https://youtu.be/dQw4w9WgXcQ')

    assert_match(%r{youtube\.com/embed/dQw4w9WgXcQ}, result)
  end

  test '本文中に単独で書かれたYouTube shorts URLもプラグイン記法なしでembedされる' do
    result = format_wiki_content('https://www.youtube.com/shorts/dQw4w9WgXcQ')

    assert_match(%r{youtube\.com/embed/dQw4w9WgXcQ}, result)
  end

  test 'YouTube embedには高さの上限（360px、幅は上限なし）が指定される' do
    result = format_wiki_content('{{youtube2 dQw4w9WgXcQ}}')

    assert_match(/h-\[360px\]/, result)
    assert_no_match(/max-w-\[\d+px\]/, result)
  end

  test '文中の一部として書かれたYouTube URLはembedされずリンクとして扱われる' do
    result = format_wiki_content('動画は https://www.youtube.com/watch?v=dQw4w9WgXcQ を見てね')

    assert_no_match(%r{youtube\.com/embed}, result)
    assert_match(%r{<a[^>]+href="https://www\.youtube\.com/watch\?v=dQw4w9WgXcQ"}, result)
  end

  test '本文中に単独で書かれたXの個別ポストURL（x.com）はプラグイン記法なしでembedされる' do
    result = format_wiki_content('https://x.com/rui_0726_dv/status/516968877503180801')

    assert_match(/twitter-tweet/, result)
    assert_match(%r{<a[^>]+href="https://x\.com/rui_0726_dv/status/516968877503180801"}, result)
    assert_match(%r{platform\.twitter\.com/widgets\.js}, result)
  end

  test '本文中に単独で書かれたXの個別ポストURL（twitter.com、クエリ文字列付き）もembedされる' do
    result = format_wiki_content("投稿はこちら\nhttps://twitter.com/rui_0726_dv/status/516968877503180801?s=20\n")

    assert_match(/twitter-tweet/, result)
    assert_match(%r{platform\.twitter\.com/widgets\.js}, result)
  end

  test '文中の一部として書かれたXの個別ポストURLはembedされずリンクとして扱われる' do
    result = format_wiki_content('投稿は https://x.com/rui_0726_dv/status/516968877503180801 を見てね')

    assert_no_match(/twitter-tweet/, result)
    assert_match(%r{<a[^>]+href="https://x\.com/rui_0726_dv/status/516968877503180801"}, result)
  end
end

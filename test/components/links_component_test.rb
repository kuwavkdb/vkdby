# frozen_string_literal: true

require 'test_helper'

class LinksComponentTest < ActionView::TestCase
  include ViewComponent::TestHelpers

  test 'link_icon returns :x for a Twitter/X URL' do
    link = Link.new(url: 'https://x.com/nonameactorsjp')

    component = LinksComponent.new(links: [link])

    assert_equal :x, component.link_icon(link)
  end

  test 'link_icon returns :instagram for an Instagram URL' do
    link = Link.new(url: 'https://instagram.com/nonameactorsjp')

    component = LinksComponent.new(links: [link])

    assert_equal :instagram, component.link_icon(link)
  end

  test 'link_icon returns :youtube for a YouTube channel URL' do
    link = Link.new(url: 'https://youtube.com/@nonameactorsjp')

    component = LinksComponent.new(links: [link])

    assert_equal :youtube, component.link_icon(link)
  end

  test 'link_icon returns :tiktok for a TikTok URL' do
    link = Link.new(url: 'https://tiktok.com/@nonameactorsjp')

    component = LinksComponent.new(links: [link])

    assert_equal :tiktok, component.link_icon(link)
  end

  test 'link_icon returns :spotify for a Spotify artist URL' do
    link = Link.new(url: 'https://open.spotify.com/artist/1sXDlFi6YNLaPGdCf9oMZR')

    component = LinksComponent.new(links: [link])

    assert_equal :spotify, component.link_icon(link)
  end

  test 'link_icon returns nil for a non-SNS URL' do
    link = Link.new(url: 'https://example.com')

    component = LinksComponent.new(links: [link])

    assert_nil component.link_icon(link)
  end

  test 'renders an SNS icon and platform name for a Twitter link' do
    link = Link.new(url: 'https://x.com/nonameactorsjp')

    render_inline(LinksComponent.new(links: [link]))

    assert_selector 'svg'
    assert_text '(Twitter)'
  end

  test 'renders the generic external-site icon and label for a non-SNS link' do
    link = Link.new(url: 'https://example.com')

    render_inline(LinksComponent.new(links: [link]))

    assert_selector 'svg'
    assert_text '(外部サイト)'
  end
end

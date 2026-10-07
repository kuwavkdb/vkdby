# frozen_string_literal: true

require 'test_helper'

# 会場ページのコメント欄（issue #1789）
class VenueCommentsTest < ActionDispatch::IntegrationTest
  test 'does not render the comments section when DISQUS_SHORTNAME is not configured' do
    venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT')

    with_disqus_shortname(nil) { get venue_path(venue.key) }

    assert_response :success
    assert_not_includes response.body, 'id="comments"'
  end

  test 'renders the comments section pointing at the old www.vkdb.jp URL when old_key is present' do
    venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', old_key: '%BF%B7%BD%C9LOFT')

    with_disqus_shortname('vkdbjp') { get venue_path(venue.key) }

    assert_response :success
    assert_includes response.body, 'id="comments"'
    assert_includes response.body, 'data-disqus-shortname="vkdbjp"'
    assert_includes response.body, 'data-disqus-page-url="https://www.vkdb.jp/%BF%B7%BD%C9LOFT.html"'
  end

  test 'renders the comments section without a page-url override when old_key is absent' do
    venue = Venue.create!(key: 'new-venue', name: '新しい会場')

    with_disqus_shortname('vkdbjp') { get venue_path(venue.key) }

    assert_response :success
    assert_includes response.body, 'id="comments"'
    assert_includes response.body, 'data-disqus-page-url=""'
  end

  private

  def with_disqus_shortname(shortname)
    original = ENV.fetch('DISQUS_SHORTNAME', nil)
    ENV['DISQUS_SHORTNAME'] = shortname
    yield
  ensure
    ENV['DISQUS_SHORTNAME'] = original
  end
end

# frozen_string_literal: true

require 'test_helper'

class SpotifyEmbedComponentTest < ActiveSupport::TestCase
  test 'render? is true for a plain artist URL' do
    link = OpenStruct.new(url: 'https://open.spotify.com/artist/1sXDlFi6YNLaPGdCf9oMZR')

    component = SpotifyEmbedComponent.new(links: [link])

    assert component.render?
    assert_equal '1sXDlFi6YNLaPGdCf9oMZR', component.spotify_artist_id
  end

  test 'render? is true for a locale-prefixed artist URL' do
    link = OpenStruct.new(url: 'https://open.spotify.com/intl-ja/artist/7w834cRqOPTd2jPySIaIva?si=6QBePpezT-qVCB7ORZPbYA')

    component = SpotifyEmbedComponent.new(links: [link])

    assert component.render?
    assert_equal '7w834cRqOPTd2jPySIaIva', component.spotify_artist_id
  end

  test 'render? is false when no link matches an artist URL' do
    link = OpenStruct.new(url: 'https://open.spotify.com/track/1sXDlFi6YNLaPGdCf9oMZR')

    component = SpotifyEmbedComponent.new(links: [link])

    refute component.render?
  end
end

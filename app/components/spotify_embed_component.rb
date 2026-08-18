# frozen_string_literal: true

class SpotifyEmbedComponent < ViewComponent::Base
  # https://open.spotify.com/artist/xxxx や https://open.spotify.com/intl-ja/artist/xxxx のような
  # locale プレフィックス付きURLにも対応する
  ARTIST_URL_PATTERN = %r{open\.spotify\.com/(?:intl-[a-zA-Z-]+/)?artist/([a-zA-Z0-9]+)}

  def initialize(links:)
    @links = links
    @spotify_link = links.find { |link| link.url&.match?(ARTIST_URL_PATTERN) }
  end

  def render?
    @spotify_link.present?
  end

  def spotify_artist_id
    # Extract artist ID from URL: https://open.spotify.com/artist/1sXDlFi6YNLaPGdCf9oMZR
    @spotify_link.url.match(ARTIST_URL_PATTERN)[1] if @spotify_link
  end
end

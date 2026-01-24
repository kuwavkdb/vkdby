class SpotifyEmbedComponent < ViewComponent::Base
  def initialize(links:)
    @links = links
    @spotify_link = links.find { |link| link.url&.include?("open.spotify.com/artist/") }
  end

  def render?
    @spotify_link.present?
  end

  def spotify_artist_id
    # Extract artist ID from URL: https://open.spotify.com/artist/1sXDlFi6YNLaPGdCf9oMZR
    @spotify_link.url.match(/artist\/([a-zA-Z0-9]+)/)[1] if @spotify_link
  end
end

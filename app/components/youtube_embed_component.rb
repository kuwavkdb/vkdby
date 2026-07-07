# frozen_string_literal: true

class YoutubeEmbedComponent < ViewComponent::Base
  def initialize(links:)
    super()
    @youtube_links = links
  end

  def render?
    @youtube_links.present?
  end
end

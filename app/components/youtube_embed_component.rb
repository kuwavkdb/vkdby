# frozen_string_literal: true

class YoutubeEmbedComponent < ViewComponent::Base
  def initialize(link:)
    super()
    @link = link
  end

  def render?
    @link&.youtube_video_id.present?
  end

  def youtube_video_id
    @link.youtube_video_id
  end
end

class LinksComponent < ViewComponent::Base
  def initialize(links:)
    @links = links
  end

  def render?
    @links.present?
  end

  private

  def embed_target
    @embed_target ||= @links.reverse.find { |l| l.youtube_video_id.present? }
  end
end

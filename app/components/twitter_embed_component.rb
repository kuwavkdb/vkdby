# frozen_string_literal: true

class TwitterEmbedComponent < ViewComponent::Base
  def initialize(links:)
    super()
    @twitter_links = links
  end

  def render?
    @twitter_links.present?
  end
end

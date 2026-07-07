# frozen_string_literal: true

class LinksComponent < ViewComponent::Base
  def initialize(links:)
    @links = links
  end

  def render?
    @links.present?
  end
end

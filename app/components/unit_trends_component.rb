# frozen_string_literal: true

class UnitTrendsComponent < ViewComponent::Base
  include WikiLinkHelper
  include Rails.application.routes.url_helpers

  def initialize(trends:)
    super()
    @trends = trends
  end

  def render?
    @trends.present?
  end
end

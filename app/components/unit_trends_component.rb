# frozen_string_literal: true

class UnitTrendsComponent < ViewComponent::Base
  include WikiLinkHelper
  include Rails.application.routes.url_helpers

  def initialize(trends:, current_trend_id: nil, top_spacing: true, resource: nil, related_units: {})
    super()
    @trends           = trends
    @current_trend_id = current_trend_id
    @top_spacing      = top_spacing
    @resource         = resource
    @related_units    = related_units
  end

  def current?(trend)
    @current_trend_id.present? && trend.id == @current_trend_id
  end

  def render?
    @trends.present?
  end
end

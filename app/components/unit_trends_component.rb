# frozen_string_literal: true

class UnitTrendsComponent < ViewComponent::Base
  include WikiLinkHelper
  include Rails.application.routes.url_helpers

  def initialize(trends:, current_trend_id: nil)
    super()
    @trends           = trends
    @current_trend_id = current_trend_id
  end

  def current?(trend)
    @current_trend_id.present? && trend.id == @current_trend_id
  end

  def render?
    @trends.present?
  end
end

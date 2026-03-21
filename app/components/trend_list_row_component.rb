# frozen_string_literal: true

class TrendListRowComponent < ViewComponent::Base
  include WikiLinkHelper
  include Rails.application.routes.url_helpers

  with_collection_parameter :trend

  def initialize(trend:, current: false)
    super()
    @trend   = trend
    @current = current
  end

  def current? = @current
end

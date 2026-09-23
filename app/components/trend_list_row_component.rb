# frozen_string_literal: true

class TrendListRowComponent < ViewComponent::Base
  include WikiLinkHelper
  include ApplicationHelper
  include TrendsHelper
  include Rails.application.routes.url_helpers

  with_collection_parameter :trend

  def initialize(trend:, current: false, resource: nil, related_units: {})
    super()
    @trend         = trend
    @current       = current
    @resource      = resource
    @related_units = related_units
  end

  def current? = @current

  # 自ユニット（resource）が動向登録時点で現在と異なる名前で登録されている場合のみ、
  # その別名をバッジ表示する。他ユニットが併記されている動向でも他ユニット名は表示しない（issue #1658）
  def unit_badges
    return [] unless @resource.is_a?(Unit) && @trend.units.present?

    unit_data = @trend.units.find { |data| data['unit_id'] == @resource.id }
    return [] if unit_data.nil?

    display_name = trend_unit_display_name(unit_data, @resource)
    return [] if display_name.blank? || display_name == @resource.name

    [display_name]
  end
end

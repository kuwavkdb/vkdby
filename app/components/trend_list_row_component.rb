# frozen_string_literal: true

class TrendListRowComponent < ViewComponent::Base
  include WikiLinkHelper
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

  # resource（現在表示中のUnit）と表記が異なるユニットのみバッジ表示対象にする
  def unit_badges
    return [] if @resource.nil? || @trend.units.blank?

    @trend.units.filter_map do |unit_data|
      unit = @related_units[unit_data['unit_id']]
      display_name = trend_unit_display_name(unit_data, unit)
      next if display_name.blank?
      next if same_as_current_resource?(unit_data, display_name)

      display_name
    end
  end

  private

  def same_as_current_resource?(unit_data, display_name)
    return false unless @resource.is_a?(Unit) && unit_data['unit_id'] == @resource.id

    display_name == @resource.name
  end
end

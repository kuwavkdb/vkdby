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

  # 個人名を件名の前に出す動向（issue #2092）のため、一覧の動向に紐づく個人をまとめて引く。
  # ユニット・個人のページと動向の詳細ページの両方で使うため、呼び出し側ではなくここで引く
  def related_people
    @related_people ||= Trend.related_people_for(@trends)
  end

  def current?(trend)
    @current_trend_id.present? && trend.id == @current_trend_id
  end

  def render?
    @trends.present?
  end
end

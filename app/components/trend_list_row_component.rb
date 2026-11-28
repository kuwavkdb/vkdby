# frozen_string_literal: true

class TrendListRowComponent < ViewComponent::Base
  include WikiLinkHelper
  include ApplicationHelper
  include TrendsHelper
  include Rails.application.routes.url_helpers

  with_collection_parameter :trend

  def initialize(trend:, current: false, resource: nil, related_units: {}, related_people: {})
    super()
    @trend          = trend
    @current        = current
    @resource       = resource
    @related_units  = related_units
    @related_people = related_people || {}
  end

  def current? = @current

  # ログイン時（管理者）にしか見えない未公開の動向。公開中の動向と見分けられるよう、破線の枠で囲む（issue #2014）
  def unpublished? = !@trend.published?

  # 件名の前に出す名前のバッジ。個人名を件名の前に出す動向（Trend詳細と同じ判定）は、ユニット名の代わりに
  # 紐づく個人の名前をすべて出す（個人のページでは本人の名前も出す、issue #2092）。それ以外は unit_badges
  def lead_badges
    return unit_badges unless trend_show_person_badge_in_title?(@trend)

    @trend.people.filter_map do |person_data|
      trend_person_display_name(person_data, @related_people[person_data['person_id']]).presence
    end
  end

  # 個人のページ（resource が Person）では、動向に設定されたユニットの名前をすべてバッジ表示する（issue #2149）。
  # ユニットのページでは、自ユニット（resource）が動向登録時点で現在と異なる名前で登録されている場合のみ、
  # その別名をバッジ表示する。他ユニットが併記されている動向でも他ユニット名は表示しない（issue #1658）
  def unit_badges
    return [] if @trend.units.blank?
    return person_page_unit_badges if @resource.is_a?(Person)
    return [] unless @resource.is_a?(Unit)

    unit_data = @trend.units.find { |data| data['unit_id'] == @resource.id }
    return [] if unit_data.nil?

    display_name = trend_unit_display_name(unit_data, @resource)
    return [] if display_name.blank? || display_name == @resource.name

    [display_name]
  end

  private

  # 名前は動向に保存された登録時の名前を優先し、無ければ今のユニット名（related_units から引く）
  def person_page_unit_badges
    @trend.units.filter_map do |unit_data|
      trend_unit_display_name(unit_data, @related_units[unit_data['unit_id']]).presence
    end.uniq
  end
end

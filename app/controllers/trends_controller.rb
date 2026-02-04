# frozen_string_literal: true

class TrendsController < ApplicationController
  def index
    dates = Trend.pluck(:date)
    @year_counts = dates.map(&:year).tally
    @years = @year_counts.keys.sort.reverse

    scope = Trend.all.order(date: :desc)


    if params[:year].present?
      year = params[:year].to_i
      month = params[:month].presence&.to_i

      target_dates = dates.select { |d| d.year == year }
      @month_counts = target_dates.map(&:month).tally
      @months = @month_counts.keys.sort.reverse

      start_date = Date.new(year, month || 1, 1)
      end_date = month ? start_date.end_of_month : start_date.end_of_year

      scope = scope.where(date: start_date..end_date)
    end

    @pagy, @trends = pagy(scope)

    all_unit_ids = @trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
    @related_units = Unit.where(id: all_unit_ids).index_by(&:id)
  end

  def show
    @trend = Trend.find(params[:id])
    return unless @trend.units.present?

    unit_ids = @trend.units.map { |u| u['unit_id'] }
    @related_units = Unit.where(id: unit_ids).index_by(&:id)
  end
end

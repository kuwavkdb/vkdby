# frozen_string_literal: true

class MonthlyController < ApplicationController
  def show
    @date = parse_date_params
    return redirect_to root_path, alert: '日付の形式が正しくありません' unless @date

    @daily_trend_counts = calculate_daily_trend_counts(@date)
    @day_unknown_trends = fetch_day_unknown_trends(@date)
    @related_units = load_related_units(@day_unknown_trends)
  end

  private

  def parse_date_params
    year = params[:year].to_i
    month = params[:month].to_i
    Date.new(year, month, 1)
  rescue ArgumentError
    nil
  end

  def calculate_daily_trend_counts(date)
    Trend
      .where('EXTRACT(YEAR FROM date) = ? AND EXTRACT(MONTH FROM date) = ?', date.year, date.month)
      .where(day_unknown: false)
      .group('EXTRACT(DAY FROM date)')
      .count
      .transform_keys(&:to_i)
  end

  def fetch_day_unknown_trends(date)
    Trend
      .where('EXTRACT(YEAR FROM date) = ? AND EXTRACT(MONTH FROM date) = ?', date.year, date.month)
      .where(day_unknown: true, month_unknown: false)
      .order(created_at: :desc)
  end

  def load_related_units(trends)
    all_unit_ids = trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
    Unit.where(id: all_unit_ids).index_by(&:id)
  end
end

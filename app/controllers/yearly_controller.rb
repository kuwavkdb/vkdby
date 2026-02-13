# frozen_string_literal: true

class YearlyController < ApplicationController
  def index
    @start_year = 1970
    @end_year = Date.today.year
    @years = (@start_year..@end_year).to_a.reverse
  end

  def show
    @year = parse_year_param
    return redirect_to root_path, alert: '年の形式が正しくありません' unless @year

    @monthly_trend_counts = calculate_monthly_trend_counts(@year)
    @month_unknown_trends = fetch_month_unknown_trends(@year)
    @related_units = load_related_units(@month_unknown_trends)
  end

  private

  def parse_year_param
    year = params[:year].to_i
    return nil if year <= 0 || year > 9999

    year
  rescue ArgumentError
    nil
  end

  def calculate_monthly_trend_counts(year)
    Trend
      .where('EXTRACT(YEAR FROM date) = ?', year)
      .where(month_unknown: false)
      .group('EXTRACT(MONTH FROM date)')
      .count
      .transform_keys(&:to_i)
  end

  def fetch_month_unknown_trends(year)
    Trend
      .where('EXTRACT(YEAR FROM date) = ?', year)
      .where(month_unknown: true)
      .order(created_at: :desc)
  end

  def load_related_units(trends)
    all_unit_ids = trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
    Unit.where(id: all_unit_ids).index_by(&:id)
  end
end

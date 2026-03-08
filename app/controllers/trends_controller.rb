# frozen_string_literal: true

class TrendsController < ApplicationController
  def index
    dates = Trend.pluck(:date)
    @year_counts = dates.map(&:year).tally
    @years = @year_counts.keys.sort.reverse

    if params[:year].present?
      year = params[:year].to_i
      month = params[:month].presence&.to_i

      target_dates = dates.select { |d| d.year == year }
      @month_counts = target_dates.map(&:month).tally
      @months = @month_counts.keys.sort.reverse

      start_date = Date.new(year, month || 1, 1)
      end_date = month ? start_date.end_of_month : start_date.end_of_year

      scope = Trend.all.order(date: :desc).where(date: start_date..end_date)
    else
      scope = Trend.all.order(id: :desc)
    end

    @pagy, @trends = pagy(scope, limit: 20)

    all_unit_ids = @trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
    @related_units = Unit.where(id: all_unit_ids).index_by(&:id)
  end

  def show
    @trend = Trend.find(params[:id])
    return unless @trend.units.present?

    unit_ids = @trend.units.map { |u| u['unit_id'] }
    @related_units = Unit.where(id: unit_ids).index_by(&:id)

    return unless unit_ids.size == 1

    unit = @related_units.values.first
    return unless unit

    candidate_date = @trend.snapshot_date || @trend.date
    @snapshot = unit.unit_snapshots
                    .includes(snapshot_people: :person)
                    .find_by(snapshot_date: candidate_date) ||
                unit.unit_snapshots
                    .includes(snapshot_people: :person)
                    .find_by(current: true)

    scopes = []
    scopes << Item.by_artist_key(unit.key) if unit.key.present?
    scopes << Item.by_artist_old_key(unit.old_key) if unit.old_key.present?
    @items = scopes.reduce(:or).order(release_date: :desc).limit(8) if scopes.any?
  end
end

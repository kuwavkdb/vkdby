# frozen_string_literal: true

class TrendsController < ApplicationController
  def index
    @year_counts = viewable_trends.group('EXTRACT(year FROM date)::integer').count
    @years = @year_counts.keys.sort.reverse

    if params[:year].present?
      year = params[:year].to_i
      month = params[:month].presence&.to_i

      @month_counts = viewable_trends.where('EXTRACT(year FROM date) = ?', year)
                                     .group('EXTRACT(month FROM date)::integer').count
      @months = @month_counts.keys.sort.reverse

      start_date = Date.new(year, month || 1, 1)
      end_date = month ? start_date.end_of_month : start_date.end_of_year

      scope = viewable_trends.order(date: :desc).where(date: start_date..end_date)
    elsif params[:sort] == 'update'
      scope = viewable_trends.order(id: :desc)
    else
      scope = viewable_trends.order(date: :desc)
    end

    @pagy, @trends = pagy(scope, limit: 20)
    @related_units = related_units_for(@trends)
  end

  def show
    @trend = viewable_trends.find(params[:id])

    # 件名前の個人名バッヂ（issue #1411）はユニット未紐付けのtrendでも表示するため、
    # @related_peopleは以下のunits.present?チェックより前で解決しておく
    person_ids = (@trend.people || []).map { |p| p['person_id'] }.compact
    @related_people = Person.kept.where(id: person_ids).index_by(&:id) if person_ids.any?

    return unless @trend.units.present?

    @related_units = related_units_for([@trend])

    first_unit_id = @trend.units.first&.dig('unit_id')
    @unit = @related_units[first_unit_id]
    return unless @unit

    unit = @unit

    candidate_date = @trend.snapshot_date || @trend.date
    @snapshot = unit.unit_snapshots
                    .includes(snapshot_people: :person)
                    .find_by(snapshot_date: candidate_date) ||
                unit.unit_snapshots
                    .includes(snapshot_people: :person)
                    .find_by(current: true)

    scopes = []
    scopes << Item.kept.by_artist_key(unit.key) if unit.key.present?
    scopes << Item.kept.by_artist_old_key(unit.old_key) if unit.old_key.present?
    @items = scopes.reduce(:or).order(release_date: :desc).limit(8) if scopes.any?

    @unit_trends = viewable_trends.where('units @> ?', [{ unit_id: unit.id }].to_json)
                                  .select(:id, :date, :title, :units)
                                  .order(date: :asc)
    @unit_trends_related_units = related_units_for(@unit_trends)
  end

  private

  # 公開画面から閲覧可能なTrendの範囲。adminロールのみ非公開（active: false・
  # 公開開始日時が未到来）のTrendも参照でき、管理画面プレビュー用途に使う
  def viewable_trends
    current_user&.admin? ? Trend.all : Trend.published
  end

  def related_units_for(trends)
    unit_ids = trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
    Unit.kept.where(id: unit_ids).index_by(&:id)
  end
end

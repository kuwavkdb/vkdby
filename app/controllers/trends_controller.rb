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
    @related_units = related_units_for([@trend]) if @trend.units.present?

    # 動向の日付と同じ発売日で、同じアーティスト（紐付いたユニット・個人）のアイテム（issue #2014）
    @same_day_items = same_day_items_for(@trend, [*@related_units&.values, *@related_people&.values])

    return unless @trend.units.present?

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
    # 同じ日に発売のアイテムとして動向の下に出したものは、重ねて出さない
    @items = scopes.reduce(:or).where.not(id: @same_day_items.map(&:id)).order(release_date: :desc).limit(8) if scopes.any?

    @unit_trends = viewable_trends.where('units @> ?', [{ unit_id: unit.id }].to_json)
                                  .select(:id, :date, :month_unknown, :day_unknown, :title, :units,
                                          :active, :publish_start_at)
                                  .order(date: :asc)
    @unit_trends_related_units = related_units_for(@unit_trends)
  end

  private

  # 公開画面から閲覧可能なTrendの範囲。adminロールのみ非公開（active: false・
  # 公開開始日時が未到来）のTrendも参照でき、管理画面プレビュー用途に使う
  def viewable_trends
    current_user&.admin? ? Trend.all : Trend.published
  end

  # 日付が確定している動向について、同じ発売日で、artists に指定のユニット・個人（key または old_key）を含むアイテム
  def same_day_items_for(trend, artists)
    return [] if trend.month_unknown? || trend.day_unknown?

    scopes = artists.flat_map do |artist|
      [(Item.by_artist_key(artist.key) if artist.key.present?),
       (Item.by_artist_old_key(artist.old_key) if artist.old_key.present?)]
    end.compact
    return [] if scopes.empty?

    Item.kept.where(release_date: trend.date).and(scopes.reduce(:or)).order(:id).to_a
  end

  def related_units_for(trends)
    unit_ids = trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
    Unit.publicly_visible.where(id: unit_ids).index_by(&:id)
  end
end

# frozen_string_literal: true

# 会場の公開ページ（issue #1691）。一覧は会場名での検索と、都道府県・エリア・種別での絞り込みができる。
# 詳細ページではその会場に紐付いた動向を日付降順で表示する
class VenuesController < ApplicationController
  def index
    base_scope = Venue.kept
    @q = params[:q].to_s.strip.presence
    @prefecture = params[:prefecture].presence_in(Venue::PREFECTURES)
    @area = params[:area].presence
    @venue_type = params[:venue_type].presence_in(Venue.venue_types.keys)

    # 都道府県の選択肢は登録のあるものだけを、Venue::PREFECTURESの並び（北から）で並べる
    prefecture_counts = base_scope.where.not(prefecture: nil).group(:prefecture).count
    @prefecture_counts = Venue::PREFECTURES.filter_map { |p| [p, prefecture_counts[p]] if prefecture_counts[p] }.to_h
    @area_counts = (base_scope.where(prefecture: @prefecture).where.not(area: [nil, '']).group(:area).count.sort.to_h if @prefecture)
    @venue_type_counts = base_scope.group(:venue_type).count

    scope = base_scope
    scope = scope.matching(normalize_search_query(@q)) if @q
    scope = scope.where(prefecture: @prefecture) if @prefecture
    scope = scope.where(area: @area) if @prefecture && @area
    scope = scope.where(venue_type: @venue_type) if @venue_type

    @pagy, @venues = pagy(scope.order(Arel.sql('COALESCE(NULLIF(name_kana, \'\'), name)'), :name), limit: 50)
    @trend_counts = Trend.published.where(venue_id: @venues.map(&:id)).group(:venue_id).count
  end

  def show
    # キー変更・統合で残した転送元（destination_key）を辿り、現在のキーへ301で転送する
    @venue = Venue.resolve_by_key(params[:key])
    raise ActiveRecord::RecordNotFound if @venue.nil? || @venue.discarded?

    if @venue.key != params[:key]
      redirect_to venue_path(@venue.key), status: :moved_permanently
      return
    end

    @links = @venue.links.where(active: true).order(:sort_order)

    # 統合でこの会場へ転送している会場（destination_keyがこの会場のキー）に紐付いた動向も含める
    venue_ids = [@venue.id] + Venue.with_discarded.where(destination_key: @venue.key).pluck(:id)
    @pagy, @trends = pagy(Trend.published.where(venue_id: venue_ids).order(date: :desc, id: :desc), limit: 50)
    unit_ids = @trends.flat_map { |t| (t.units || []).map { |u| u['unit_id'] } }.compact.uniq
    @related_units = Unit.publicly_visible.where(id: unit_ids).index_by(&:id)
  end
end

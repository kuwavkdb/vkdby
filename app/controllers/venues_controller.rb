# frozen_string_literal: true

# 会場の公開ページ（issue #1691）。一覧（/venues）は都道府県を選ぶ画面で、地方ごとに都道府県と会場数を並べ、
# 都道府県ページ（/venues/area/:prefecture、issue #1801）へ案内する（issue #1810）。
# 詳細ページではその会場に紐付いた動向を日付降順で表示する
class VenuesController < ApplicationController
  include SidebarLoadable

  # 旧一覧の検索・絞り込み・ページ送りのクエリ（issue #1810で廃止）。付いていれば新しいページへ301で転送する
  LEGACY_INDEX_PARAMS = %w[q prefecture area venue_type page].freeze

  # 詳細ページはユニット・個人のページと同じくサイドバーを表示する
  before_action :load_sidebar_data, only: :show

  def index
    return redirect_to(legacy_index_redirect_path, status: :moved_permanently) if legacy_index_params?

    # 都道府県 => 会場数。都道府県が未設定の会場はnilのキーに入る
    @prefecture_counts = Venue.kept.group(:prefecture).count
    @unassigned_count = @prefecture_counts[nil].to_i
    @total_count = @prefecture_counts.values.sum
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
    # 個人名を件名の前に出す動向の個人（Trend詳細と同じくPerson.kept、issue #1796）
    person_ids = @trends.flat_map { |t| (t.people || []).map { |p| p['person_id'] } }.compact.uniq
    @related_people = Person.kept.where(id: person_ids).index_by(&:id)
  end

  private

  def legacy_index_params?
    LEGACY_INDEX_PARAMS.any? { |key| params.key?(key) }
  end

  # 旧一覧のURLの転送先。都道府県（とエリア）の指定があればそのページへ（種別も引き継ぐ）、
  # それ以外（検索語・種別だけ・不正な値）は都道府県選択画面へ
  def legacy_index_redirect_path
    prefecture = params[:prefecture].presence_in(Venue::PREFECTURES)
    return venues_path unless prefecture && Venue.kept.exists?(prefecture: prefecture)

    venue_type = params[:venue_type].presence_in(Venue.venue_types.keys)
    area = params[:area].to_s.strip.presence
    if area && Venue.area_page_segment?(area) && Venue.kept.exists?(prefecture: prefecture, area: area)
      venue_area_path(prefecture, area, venue_type: venue_type)
    else
      venue_prefecture_path(prefecture, venue_type: venue_type)
    end
  end
end

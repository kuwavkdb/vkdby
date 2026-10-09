# frozen_string_literal: true

# 都道府県ページ・エリアページ（issue #1801）。範囲内の会場を地図と一覧で表示する。
# URLは /venues/area/:prefecture（都道府県ページ）と /venues/area/:prefecture/:area（エリアページ）で、
# 都道府県・エリアの値をそのまま使う。都道府県ページにはエリアが空の会場も含める。
# /venues/area/未設定 は都道府県が未設定の会場の一覧（issue #1810）。
# ?venue_type= で種別を絞り込める（issue #1810）。
# 地図にプロットするのは座標があり、閉店・配信ではない会場（Venue.mappable）。一覧は会場一覧と同じく全件を表示する
class VenueAreasController < ApplicationController
  def show
    # Middleware::EucJpUrlFixer がパス中の%XXを%25XXに再エンコードするため、日本語の値は
    # パーセントエンコードされたまま届く。ここでデコードする
    @prefecture = decode_percent_encoded_key(params[:prefecture])
    @area = decode_percent_encoded_key(params[:area]).presence
    @unassigned = @prefecture == Venue::UNASSIGNED_PREFECTURE
    raise ActiveRecord::RecordNotFound unless valid_range?

    range = range_scope
    # 範囲に会場が1件もなければ404。種別で絞り込んだ結果が0件のときは404にせず空の一覧を出す
    raise ActiveRecord::RecordNotFound unless range.exists?

    @venue_type_counts = range.group(:venue_type).count
    @venue_type = params[:venue_type].presence_in(Venue.venue_types.keys)
    scope = @venue_type ? range.where(venue_type: @venue_type) : range
    @venues = scope.order(Arel.sql("COALESCE(NULLIF(name_kana, ''), name)"), :name).to_a
    @map_venues = @venues.select(&:mappable?)
    @area_counts = area_counts unless @area || @unassigned
    # 動向件数の列は会場一覧と同じくログイン時のみ表示する（issue #1783）
    @trend_counts = Trend.published.where(venue_id: @venues.map(&:id)).group(:venue_id).count if logged_in?
  end

  private

  # 都道府県未設定の一覧にはエリアページを作らない
  def valid_range?
    return @area.nil? if @unassigned

    Venue::PREFECTURES.include?(@prefecture)
  end

  def range_scope
    return Venue.kept.where(prefecture: nil) if @unassigned

    scope = Venue.kept.where(prefecture: @prefecture)
    @area ? scope.where(area: @area) : scope
  end

  # 都道府県ページに並べるエリアページへのリンク（エリア名 => 会場数）
  def area_counts
    Venue.kept.where(prefecture: @prefecture).where.not(area: [nil, '']).group(:area).count
         .select { |area, _| Venue.area_page_segment?(area) }.sort.to_h
  end
end

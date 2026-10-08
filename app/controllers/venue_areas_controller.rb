# frozen_string_literal: true

# 都道府県ページ・エリアページ（issue #1801）。範囲内の会場を地図と一覧で表示する。
# URLは /venues/area/:prefecture（都道府県ページ）と /venues/area/:prefecture/:area（エリアページ）で、
# 都道府県・エリアの値をそのまま使う。都道府県ページにはエリアが空の会場も含める。
# 地図にプロットするのは座標があり、閉店・配信ではない会場（Venue.mappable）。一覧は会場一覧と同じく全件を表示する
class VenueAreasController < ApplicationController
  def show
    # Middleware::EucJpUrlFixer がパス中の%XXを%25XXに再エンコードするため、日本語の値は
    # パーセントエンコードされたまま届く。ここでデコードする
    @prefecture = decode_percent_encoded_key(params[:prefecture])
    raise ActiveRecord::RecordNotFound unless Venue::PREFECTURES.include?(@prefecture)

    @area = decode_percent_encoded_key(params[:area]).presence
    scope = Venue.kept.where(prefecture: @prefecture)
    scope = scope.where(area: @area) if @area
    @venues = scope.order(Arel.sql("COALESCE(NULLIF(name_kana, ''), name)"), :name).to_a
    raise ActiveRecord::RecordNotFound if @venues.empty?

    @map_venues = @venues.select(&:mappable?)
    @area_counts = area_counts unless @area
    # 動向件数の列は会場一覧と同じくログイン時のみ表示する（issue #1783）
    @trend_counts = Trend.published.where(venue_id: @venues.map(&:id)).group(:venue_id).count if logged_in?
  end

  private

  # 都道府県ページに並べるエリアページへのリンク（エリア名 => 会場数）
  def area_counts
    Venue.kept.where(prefecture: @prefecture).where.not(area: [nil, '']).group(:area).count
         .select { |area, _| Venue.area_page_segment?(area) }.sort.to_h
  end
end

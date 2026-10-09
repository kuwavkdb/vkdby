# frozen_string_literal: true

# 都道府県・エリアページの会場の地図（issue #1801）。
# 地図に渡す会場データは地図ライブラリに依存しない形（名前・URL・種別・緯度・経度）で組み立て、
# Stimulus コントローラー（venue-map）に data 属性で渡す。どのライブラリで描くかは
# JavaScript 側のアダプター（app/javascript/venue_map/*_adapter.js）が受け持つ。
module VenueMapHelper
  # 使う地図アダプター。Google マップに切り替えるときはアダプターを足してここを変える（docs/venue_map.md）
  VENUE_MAP_PROVIDER = 'leaflet'
  # 会場が1件だけ・近接しているときに寄りすぎないための最大ズーム
  VENUE_MAP_MAX_ZOOM = 16

  def venue_map_data(venues)
    venues.map do |venue|
      {
        name: venue.name,
        url: venue_path(venue.key),
        type: venue.venue_type_text,
        lat: venue.latitude.to_f,
        lng: venue.longitude.to_f
      }
    end
  end

  def venue_map_options
    { maxZoom: VENUE_MAP_MAX_ZOOM }
  end

  # 都道府県ページ・エリアページのURL。URLの1段に使えない値（「/」入り）のときはnil
  def venue_area_page_path(prefecture, area = nil)
    return nil unless Venue::PREFECTURES.include?(prefecture)
    return venue_prefecture_path(prefecture) if area.blank?

    venue_area_path(prefecture, area) if Venue.area_page_segment?(area)
  end
end

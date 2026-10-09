# frozen_string_literal: true

require 'test_helper'

# 都道府県ページ・エリアページ（issue #1801）
class VenueAreasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @loft = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', prefecture: '東京都', area: '新宿',
                          latitude: 35.69384, longitude: 139.703549)
    @marz = Venue.create!(key: 'shinjuku-marz', name: '新宿MARZ', prefecture: '東京都', area: '新宿')
    @closed = Venue.create!(key: 'closed-hall', name: '閉店したホール', prefecture: '東京都', area: '新宿',
                            status: :closed, latitude: 35.69, longitude: 139.70)
    @budokan = Venue.create!(key: 'nippon-budokan', name: '日本武道館', prefecture: '東京都', area: '九段下',
                             venue_type: :hall, latitude: 35.6933, longitude: 139.7498)
    @no_area = Venue.create!(key: 'tokyo-somewhere', name: 'エリア未設定の会場', prefecture: '東京都',
                             latitude: 35.68, longitude: 139.76)
    @osaka = Venue.create!(key: 'osaka-muse', name: '心斎橋MUSE', prefecture: '大阪府', area: '心斎橋',
                           latitude: 34.67, longitude: 135.50)
  end

  def map_venues
    element = css_select('[data-controller="venue-map"]').first
    assert element, '地図の要素がない'
    JSON.parse(element['data-venue-map-venues-value'])
  end

  test 'prefecture page lists all venues in the prefecture including those without an area' do
    get venue_prefecture_path('東京都')

    assert_response :success
    assert_select 'h1', text: /東京都/
    assert_select 'table tbody tr', count: 5
    %w[新宿LOFT 新宿MARZ 閉店したホール 日本武道館 エリア未設定の会場].each do |name|
      assert_select 'table tbody th a', text: name
    end
    assert_select 'table tbody th a', text: '心斎橋MUSE', count: 0
  end

  test 'prefecture page links to its area pages' do
    get venue_prefecture_path('東京都')

    assert_select "nav[aria-label='エリア'] a[href='#{venue_area_path('東京都', '新宿')}']", text: /新宿\s*\(3\)/
    assert_select "nav[aria-label='エリア'] a[href='#{venue_area_path('東京都', '九段下')}']", text: /九段下\s*\(1\)/
  end

  test 'map plots venues with coordinates and leaves out closed ones' do
    get venue_prefecture_path('東京都')

    venues = map_venues
    assert_equal %w[エリア未設定の会場 新宿LOFT 日本武道館].sort, venues.pluck('name').sort
    loft = venues.find { |v| v['name'] == '新宿LOFT' }
    assert_equal({ 'name' => '新宿LOFT', 'url' => venue_path('shinjuku-loft'), 'type' => 'ライブハウス',
                   'lat' => 35.69384, 'lng' => 139.703549 }, loft)
    assert_select "[data-controller='venue-map'][data-venue-map-provider-value='leaflet']"
    assert_select "[data-venue-map-target='canvas'][aria-label='東京都の会場の地図（3件）']"
  end

  test 'area page shows only the venues in the area' do
    get venue_area_path('東京都', '新宿')

    assert_response :success
    assert_select 'h1', text: /東京都 新宿/
    assert_select 'table tbody tr', count: 3
    assert_select 'table tbody th a', text: '日本武道館', count: 0
    assert_equal ['新宿LOFT'], map_venues.pluck('name')
    assert_select "nav[aria-label='パンくずリスト'] a[href='#{venue_prefecture_path('東京都')}']", text: '東京都'
    assert_select "nav[aria-label='エリア']", count: 0
  end

  test 'area page without mappable venues shows only the list' do
    Venue.create!(key: 'shibuya-quattro', name: '渋谷クアトロ', prefecture: '東京都', area: '渋谷')

    get venue_area_path('東京都', '渋谷')

    assert_response :success
    assert_select 'table tbody th a', text: '渋谷クアトロ'
    assert_select '[data-controller="venue-map"]', count: 0
  end

  test 'returns 404 for an unknown prefecture or a range without venues' do
    get venue_prefecture_path('存在しない県')
    assert_response :not_found

    get venue_prefecture_path('北海道')
    assert_response :not_found

    get venue_area_path('東京都', '存在しないエリア')
    assert_response :not_found
  end

  test 'excludes discarded venues' do
    @osaka.discard

    get venue_prefecture_path('大阪府')

    assert_response :not_found
  end

  test 'area names with a dot are not treated as a format' do
    Venue.create!(key: 'dotted', name: 'ドットのある会場', prefecture: '東京都', area: '下北沢.SHELTER')

    get venue_area_path('東京都', '下北沢.SHELTER')

    assert_response :success
    assert_select 'table tbody th a', text: 'ドットのある会場'
  end

  test 'venue page links its prefecture and area to the area pages' do
    get venue_path(@loft.key)

    assert_select "a[href='#{venue_prefecture_path('東京都')}']", text: '東京都'
    assert_select "a[href='#{venue_area_path('東京都', '新宿')}']", text: '新宿'
  end

  test 'venue index links to the area page of the selected prefecture and area' do
    get venues_path(prefecture: '東京都')
    assert_select "a[href='#{venue_prefecture_path('東京都')}']", text: /東京都の会場を地図で見る/

    get venues_path(prefecture: '東京都', area: '新宿')
    assert_select "a[href='#{venue_area_path('東京都', '新宿')}']", text: /東京都 新宿の会場を地図で見る/
  end
end

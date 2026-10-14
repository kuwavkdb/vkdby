# frozen_string_literal: true

require 'test_helper'

# 構造化データ（JSON-LD）の出力（issue #1254）
class JsonLdTest < ActionDispatch::IntegrationTest
  def json_ld_data
    scripts = css_select('script[type="application/ld+json"]')
    assert_equal 1, scripts.size
    JSON.parse(scripts.first.text)
  end

  test '作品詳細はMusicAlbumを出力する' do
    unit = Unit.create!(name: 'JsonLd Unit', key: 'json-ld-unit', status: :active)
    person = Person.create!(name: 'JsonLd Person', key: 'json-ld-person', status: :active)
    item = Item.create!(title: 'JsonLd Album', release_date: '2026-03-01', link_url: 'http://example.com/json-ld-item',
                        image_url: 'https://example.com/jacket.jpg',
                        artists: [{ 'name' => unit.name, 'key' => unit.key },
                                  { 'name' => person.name, 'key' => person.key },
                                  { 'name' => 'ページのないアーティスト' }])

    get item_path(item)

    data = json_ld_data
    assert_equal 'MusicAlbum', data['@type']
    assert_equal 'JsonLd Album', data['name']
    assert_equal '2026-03-01', data['datePublished']
    assert_equal 'https://example.com/jacket.jpg', data['image']
    assert_equal "http://www.example.com#{item_path(item)}", data['url']
    assert_equal [
      { '@type' => 'MusicGroup', 'name' => 'JsonLd Unit', 'url' => 'http://www.example.com/json-ld-unit' },
      { '@type' => 'Person', 'name' => 'JsonLd Person', 'url' => 'http://www.example.com/json-ld-person' },
      { '@type' => 'MusicGroup', 'name' => 'ページのないアーティスト' }
    ], data['byArtist']
  end

  test '会場詳細はMusicVenueを出力し、空の項目は出さない' do
    venue = Venue.create!(key: 'json-ld-venue', name: '新宿LOFT', prefecture: '東京都', capacity: 550,
                          address: 'MAP:東京都新宿区歌舞伎町1-12-9', latitude: 35.6948, longitude: 139.7012,
                          name_log: [{ 'name' => '旧LOFT' }, { 'name' => '新宿LOFT' }],
                          aliases: [{ 'name' => 'LOFT' }, { 'name' => '非表示の別名', 'hidden' => true }])
    bare = Venue.create!(key: 'json-ld-bare-venue', name: '情報の少ない会場')

    get venue_path(venue.key)

    data = json_ld_data
    assert_equal 'MusicVenue', data['@type']
    assert_equal '新宿LOFT', data['name']
    assert_equal %w[LOFT 旧LOFT], data['alternateName']
    assert_equal({ '@type' => 'PostalAddress', 'streetAddress' => '東京都新宿区歌舞伎町1-12-9',
                   'addressRegion' => '東京都', 'addressCountry' => 'JP' }, data['address'])
    assert_equal({ '@type' => 'GeoCoordinates', 'latitude' => 35.6948, 'longitude' => 139.7012 }, data['geo'])
    assert_equal 550, data['maximumAttendeeCapacity']

    get venue_path(bare.key)

    data = json_ld_data
    assert_equal %w[@context @type name url], data.keys
  end

  test 'トップページはWebSiteを出力する' do
    CustomPage.create!(key: 'index', title: 'トップページ', active: true, body: 'body')

    get root_path

    data = json_ld_data
    assert_equal 'WebSite', data['@type']
    assert_equal Rails.application.config.site_name, data['name']
    assert_equal 'http://www.example.com/', data['url']
  end

  test '値に</script>が含まれていてもタグを閉じない' do
    item = Item.create!(title: '</script><script>alert(1)</script>', release_date: '2026-03-01',
                        link_url: 'http://example.com/json-ld-escape-item')

    get item_path(item)

    assert_not_includes response.body, '</script><script>alert(1)'
    assert_equal '</script><script>alert(1)</script>', json_ld_data['name']
  end
end

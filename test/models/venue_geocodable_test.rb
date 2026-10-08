# frozen_string_literal: true

require 'test_helper'

# 会場の座標（issue #1801）
class VenueGeocodableTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
  include ActiveJob::TestHelper

  def create_venue(**attrs)
    Venue.create!({ key: "venue-#{SecureRandom.hex(4)}", name: '会場' }.merge(attrs))
  end

  test 'geocode_query prepends the prefecture when the address does not include it' do
    assert_equal '東京都新宿区歌舞伎町1-12-9',
                 Venue.new(prefecture: '東京都', address: '新宿区歌舞伎町1-12-9').geocode_query
    assert_equal '東京都新宿区歌舞伎町1-12-9',
                 Venue.new(prefecture: '東京都', address: '東京都新宿区歌舞伎町1-12-9').geocode_query
    assert_equal '東京都新宿区歌舞伎町1-12-9', Venue.new(address: 'MAP:東京都新宿区歌舞伎町1-12-9').geocode_query
  end

  test 'geocode_query is nil for streaming, overseas and address-less venues' do
    assert_nil Venue.new(address: '東京都新宿区', venue_type: :streaming).geocode_query
    assert_nil Venue.new(address: 'Los Angeles', prefecture: '海外').geocode_query
    assert_nil Venue.new(prefecture: '東京都').geocode_query
  end

  test 'creating a venue with an address enqueues geocoding' do
    assert_enqueued_with(job: GeocodeVenueJob) do
      create_venue(address: '東京都新宿区歌舞伎町1-12-9')
    end
  end

  test 'changing the address enqueues geocoding but other changes do not' do
    venue = create_venue(address: '東京都新宿区歌舞伎町1-12-9')

    assert_no_enqueued_jobs(only: GeocodeVenueJob) { venue.update!(name: '新しい名前') }
    assert_enqueued_with(job: GeocodeVenueJob, args: [venue.id]) { venue.update!(address: '東京都渋谷区') }
  end

  test 'entering coordinates marks them as manual and stops automatic geocoding' do
    venue = create_venue(address: '東京都新宿区歌舞伎町1-12-9')

    venue.update!(latitude: '35.7', longitude: '139.7')
    assert venue.coordinates_manual?

    assert_no_enqueued_jobs(only: GeocodeVenueJob) { venue.update!(address: '東京都渋谷区') }
  end

  test 'clearing manual coordinates returns to automatic geocoding' do
    venue = create_venue(address: '東京都新宿区歌舞伎町1-12-9', latitude: 35.7, longitude: 139.7)
    assert venue.coordinates_manual?

    assert_enqueued_with(job: GeocodeVenueJob, args: [venue.id]) do
      venue.update!(latitude: '', longitude: '')
    end
    assert_nil venue.reload.coordinates_source
  end

  test 'latitude and longitude must be entered together and within range' do
    assert_not Venue.new(key: 'a', name: 'a', latitude: 35.7).valid?
    assert_not Venue.new(key: 'a', name: 'a', latitude: 91, longitude: 139.7).valid?
    assert_not Venue.new(key: 'a', name: 'a', latitude: 35.7, longitude: 181).valid?
    assert Venue.new(key: 'a', name: 'a', latitude: 35.7, longitude: 139.7).valid?
  end

  test 'geocode! saves the coordinates without touching updated_at' do
    venue = create_venue(prefecture: '東京都', address: '新宿区歌舞伎町1-12-9')
    updated_at = venue.reload.updated_at
    queries = []

    stub_class_method(GsiGeocoder, :call, lambda { |query|
      queries << query
      [35.69384, 139.703549]
    }) do
      assert venue.geocode!
    end

    venue.reload
    assert_equal ['東京都新宿区歌舞伎町1-12-9'], queries
    assert_in_delta 35.69384, venue.latitude.to_f, 0.000001
    assert_in_delta 139.703549, venue.longitude.to_f, 0.000001
    assert venue.coordinates_geocoded?
    assert_equal updated_at, venue.updated_at
  end

  test 'geocode! does not overwrite manual coordinates' do
    venue = create_venue(address: '東京都新宿区歌舞伎町1-12-9', latitude: 35.1, longitude: 139.1)

    stub_class_method(GsiGeocoder, :call, ->(_query) { raise 'should not be called' }) do
      assert_not venue.geocode!
    end

    assert_in_delta 35.1, venue.reload.latitude.to_f, 0.000001
    assert venue.coordinates_manual?
  end

  test 'geocode! clears automatic coordinates when the address is no longer found' do
    venue = create_venue(address: '東京都新宿区歌舞伎町1-12-9')
    venue.update_columns(latitude: 35.1, longitude: 139.1, coordinates_source: Venue.coordinates_sources[:geocoded])

    stub_class_method(GsiGeocoder, :call, nil) do
      assert_not venue.geocode!
    end

    venue.reload
    assert_nil venue.latitude
    assert_nil venue.longitude
    assert_nil venue.coordinates_source
  end

  test 'mappable excludes closed, streaming and coordinate-less venues' do
    open_venue = create_venue(latitude: 35.7, longitude: 139.7)
    closed = create_venue(latitude: 35.7, longitude: 139.7, status: :closed)
    streaming = create_venue(latitude: 35.7, longitude: 139.7, venue_type: :streaming)
    no_coordinates = create_venue

    mappable = Venue.mappable.to_a
    assert_includes mappable, open_venue
    assert_not_includes mappable, closed
    assert_not_includes mappable, streaming
    assert_not_includes mappable, no_coordinates
    assert open_venue.mappable?
    assert_not closed.mappable?
  end

  test 'geocode_all fetches coordinates of venues without them and skips manual ones' do
    missing = create_venue(address: '東京都新宿区歌舞伎町1-12-9')
    not_found = create_venue(address: '存在しない住所')
    manual = create_venue(address: '東京都渋谷区', latitude: 35.1, longitude: 139.1)
    create_venue(prefecture: '東京都') # 住所なし（問い合わせない）

    queried = []
    stub_class_method(GsiGeocoder, :call, lambda { |query|
      queried << query
      query == '存在しない住所' ? nil : [35.69384, 139.703549]
    }) do
      assert_equal({ geocoded: 1, not_found: 1, failed: 0 }, Venue.geocode_all(interval: 0))
    end

    assert_equal %w[存在しない住所 東京都新宿区歌舞伎町1-12-9], queried.sort
    assert missing.reload.coordinates_geocoded?
    assert_nil not_found.reload.latitude
    assert manual.reload.coordinates_manual?
  end

  test 'geocode_all counts API failures and continues' do
    create_venue(address: '東京都新宿区歌舞伎町1-12-9')

    stub_class_method(GsiGeocoder, :call, ->(_query) { raise GsiGeocoder::Error, 'timeout' }) do
      assert_equal({ geocoded: 0, not_found: 0, failed: 1 }, Venue.geocode_all(interval: 0))
    end
  end
end

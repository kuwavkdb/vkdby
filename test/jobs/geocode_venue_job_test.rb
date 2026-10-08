# frozen_string_literal: true

require 'test_helper'

# 会場の座標の自動取得ジョブ（issue #1801）
class GeocodeVenueJobTest < ActiveJob::TestCase
  test 'perform saves the coordinates of the venue' do
    venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', address: '東京都新宿区歌舞伎町1-12-9')

    stub_class_method(GsiGeocoder, :call, [35.69384, 139.703549]) do
      GeocodeVenueJob.perform_now(venue.id)
    end

    assert venue.reload.coordinates_geocoded?
    assert_in_delta 35.69384, venue.latitude.to_f, 0.000001
  end

  test 'perform skips discarded venues' do
    venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', address: '東京都新宿区歌舞伎町1-12-9')
    venue.discard

    stub_class_method(GsiGeocoder, :call, ->(_query) { raise 'should not be called' }) do
      GeocodeVenueJob.perform_now(venue.id)
    end

    assert_nil venue.reload.latitude
  end
end

# frozen_string_literal: true

require 'test_helper'

# 国土地理院の住所検索APIによる座標の取得（issue #1801）
class GsiGeocoderTest < ActiveSupport::TestCase
  RESPONSE = [
    { 'geometry' => { 'coordinates' => [139.703549, 35.69384], 'type' => 'Point' },
      'type' => 'Feature', 'properties' => { 'addressCode' => '', 'title' => '東京都新宿区歌舞伎町一丁目' } },
    { 'geometry' => { 'coordinates' => [139.7, 35.6], 'type' => 'Point' },
      'type' => 'Feature', 'properties' => { 'addressCode' => '', 'title' => '別の候補' } }
  ].to_json

  test 'call returns the latitude and longitude of the first candidate' do
    queries = []
    stub_class_method(GsiGeocoder, :fetch, lambda { |query|
      queries << query
      RESPONSE
    }) do
      assert_equal [35.69384, 139.703549], GsiGeocoder.call('東京都新宿区歌舞伎町1-12-9')
    end
    assert_equal ['東京都新宿区歌舞伎町1-12-9'], queries
  end

  test 'call returns nil when nothing matches' do
    stub_class_method(GsiGeocoder, :fetch, '[]') do
      assert_nil GsiGeocoder.call('存在しない住所')
    end
  end

  test 'parse raises an error for an unexpected response' do
    assert_raises(GsiGeocoder::Error) { GsiGeocoder.parse('<html>error</html>') }
    assert_raises(GsiGeocoder::Error) { GsiGeocoder.parse('{"message":"error"}') }
  end
end

# frozen_string_literal: true

require 'net/http'

# 国土地理院の住所検索API（API キー不要）で、住所から座標を求める（issue #1801）。
# 都道府県・エリアページの地図に会場をプロットするために使う。座標は世界測地系の10進数の度。
#
#   GsiGeocoder.call('東京都新宿区歌舞伎町1-12-9') # => [35.69, 139.70]（見つからなければnil）
#
# 通信の失敗・想定外の応答は GsiGeocoder::Error を投げる（「見つからなかった」と区別して、
# 呼び出し元が既存の座標を消さずに再試行できるように）。
class GsiGeocoder
  ENDPOINT = 'https://msearch.gsi.go.jp/address-search/AddressSearch'
  TIMEOUT = 5

  class Error < StandardError; end

  def self.call(query)
    parse(fetch(query))
  end

  # APIの応答本文を返す。テストではこのメソッドを差し替える
  def self.fetch(query)
    uri = URI(ENDPOINT)
    uri.query = URI.encode_www_form(q: query)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.get(uri.request_uri)
    end
    raise Error, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response.body
  rescue Error
    raise
  rescue StandardError => e
    raise Error, "#{e.class}: #{e.message}"
  end

  # 応答（GeoJSONのFeatureの配列。座標は [経度, 緯度] の順）の先頭の候補を [緯度, 経度] で返す
  def self.parse(body)
    features = JSON.parse(body.to_s)
    raise Error, 'unexpected response' unless features.is_a?(Array)

    longitude, latitude = features.first&.dig('geometry', 'coordinates')
    return nil unless latitude.is_a?(Numeric) && longitude.is_a?(Numeric)

    [latitude, longitude]
  rescue JSON::ParserError => e
    raise Error, "invalid JSON: #{e.message}"
  end
end

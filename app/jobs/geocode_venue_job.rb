# frozen_string_literal: true

# 会場の住所から座標を取得して保存する（issue #1801）。会場の作成・住所の変更時に
# VenueGeocodable から積まれる。保存処理をAPIの応答待ちにしない・APIの障害で保存を失敗させないため、
# バックグラウンドで実行する。
class GeocodeVenueJob < ApplicationJob
  queue_as :default

  retry_on GsiGeocoder::Error, wait: 1.minute, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(venue_id)
    venue = Venue.with_discarded.find(venue_id)
    return if venue.discarded?

    venue.geocode!
  end
end

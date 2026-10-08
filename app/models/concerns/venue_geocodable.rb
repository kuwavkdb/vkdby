# frozen_string_literal: true

# 会場の座標（issue #1801）。都道府県・エリアページの地図にプロットするために持つ。
#
# - 座標は住所から国土地理院の住所検索API（GsiGeocoder）で自動取得する。会場の作成・住所などの
#   変更時にバックグラウンドジョブ（GeocodeVenueJob）で取得し、既存の会場は rake venues:geocode でまとめて取得する
# - 管理画面で緯度・経度を入力すると手入力（coordinates_source: manual）になり、以後は自動取得で上書きしない。
#   緯度・経度を両方空にすると自動取得に戻る
# - 自動取得はupdate_columnsで保存し、updated_atは変えない（座標の取得だけで「最近の更新」に出ないように）
# - #1784（住所を複数持てるようにする）の後も、座標は代表の住所の分だけここに持つ
module VenueGeocodable
  extend ActiveSupport::Concern

  # 国土地理院の住所検索は国内の住所のみが対象のため、自動取得しない都道府県
  NON_GEOCODABLE_PREFECTURES = %w[海外].freeze
  # rake venues:geocode で、APIへの問い合わせの間に空ける秒数
  GEOCODE_ALL_INTERVAL = 1

  included do
    enum :coordinates_source, { geocoded: 0, manual: 1 }, prefix: :coordinates

    validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90,
                                         message: 'は-90〜90の数値で入力してください' }, allow_nil: true
    validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180,
                                          message: 'は-180〜180の数値で入力してください' }, allow_nil: true
    validate :coordinates_must_be_paired

    before_save :sync_coordinates_source
    after_commit :enqueue_geocoding, on: %i[create update], if: :geocoding_needed?

    # 地図にプロットする会場。座標があり、閉店・配信（物理的な所在地がない）ではないもの。
    # 論理削除・転送元のスタブの除外は呼び出し側（Venue.kept）で行う
    scope :mappable, lambda {
      where.not(latitude: nil).where.not(longitude: nil).where.not(status: :closed).where.not(venue_type: :streaming)
    }
  end

  class_methods do
    # 座標のない会場（force: trueなら手入力以外のすべての会場）の座標をまとめて取得する（rake venues:geocode）。
    # 結果の件数を { geocoded:, not_found:, failed: } で返す
    def geocode_all(force: false, interval: GEOCODE_ALL_INTERVAL, logger: Rails.logger)
      scope = kept.where(coordinates_source: [nil, :geocoded])
      scope = scope.where(latitude: nil) unless force
      counts = { geocoded: 0, not_found: 0, failed: 0 }
      scope.find_each do |venue|
        next unless venue.geocode_query

        counts[venue.geocode! ? :geocoded : :not_found] += 1
        sleep(interval) if interval.positive?
      rescue GsiGeocoder::Error => e
        counts[:failed] += 1
        logger.warn("[venues:geocode] #{venue.key}: #{e.message}")
      end
      counts
    end
  end

  # 座標の取得に使う住所。配信・海外の会場、住所のない会場はnil。
  # 住所に都道府県が書かれていない場合は、都道府県を先頭に補う
  def geocode_query
    return nil if streaming? || NON_GEOCODABLE_PREFECTURES.include?(prefecture)

    address = display_address
    return nil unless address
    return address if prefecture.blank? || address.start_with?(prefecture)

    "#{prefecture}#{address}"
  end

  # 住所から座標を取得して保存する。手入力の座標は上書きしない。
  # 取得できたらtrue。見つからなかった・住所がない場合は自動取得の座標を消してfalse
  def geocode!
    return false if coordinates_manual?

    query = geocode_query
    coordinates = query && GsiGeocoder.call(query)
    if coordinates
      update_columns(latitude: coordinates[0], longitude: coordinates[1],
                     coordinates_source: self.class.coordinates_sources[:geocoded])
      true
    else
      update_columns(latitude: nil, longitude: nil, coordinates_source: nil) if coordinates?
      false
    end
  end

  def coordinates?
    latitude.present? && longitude.present?
  end

  def mappable?
    coordinates? && !closed? && !streaming?
  end

  private

  def coordinates_must_be_paired
    return if latitude.nil? == longitude.nil?

    errors.add(:base, '緯度と経度は両方入力するか、両方空にしてください')
  end

  # 緯度・経度が（自動取得以外で）変更されたら手入力として扱う。両方空にしたら自動取得に戻す
  def sync_coordinates_source
    return unless will_save_change_to_latitude? || will_save_change_to_longitude?

    self.coordinates_source = coordinates? ? :manual : nil
  end

  def geocoding_needed?
    return false if coordinates_manual?

    saved_change_to_address? || saved_change_to_prefecture? || saved_change_to_venue_type? ||
      saved_change_to_coordinates_source?
  end

  def enqueue_geocoding
    GeocodeVenueJob.perform_later(id)
  end
end

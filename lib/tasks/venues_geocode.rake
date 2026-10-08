# frozen_string_literal: true

# 会場の座標を住所からまとめて取得する（issue #1801）。都道府県・エリアページの地図に使う。
#
#   bundle exec rails venues:geocode            # 座標のない会場だけ
#   FORCE=1 bundle exec rails venues:geocode    # 手入力以外のすべての会場を取り直す
#
# 国土地理院の住所検索APIに1件ずつ問い合わせる（間隔はVenueGeocodable::GEOCODE_ALL_INTERVAL秒）。
# 管理画面で手入力した座標は上書きしない。
namespace :venues do
  desc '会場の住所から座標をまとめて取得する（FORCE=1で手入力以外を取り直す）'
  task geocode: :environment do
    counts = Venue.geocode_all(force: ENV['FORCE'].present?)
    puts "取得: #{counts[:geocoded]}件 / 見つからず: #{counts[:not_found]}件 / 失敗: #{counts[:failed]}件"
  end
end

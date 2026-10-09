# frozen_string_literal: true

# 会場の座標を住所からまとめて取得する（issue #1801）。都道府県・エリアページの地図に使う。
#
#   bundle exec rails venues:geocode                          # 座標のない会場だけ
#   FORCE=1 bundle exec rails venues:geocode                  # 手入力以外のすべての会場を取り直す
#   PREFECTURE=東京都 bundle exec rails venues:geocode         # 都道府県を絞る
#   PREFECTURE=東京都,神奈川県 bundle exec rails venues:geocode # 複数はカンマ区切り（FORCE=1と併用可）
#
# 国土地理院の住所検索APIに1件ずつ問い合わせる（間隔はVenueGeocodable::GEOCODE_ALL_INTERVAL秒）。
# 管理画面で手入力した座標は上書きしない。
namespace :venues do
  desc '会場の住所から座標をまとめて取得する（FORCE=1で手入力以外を取り直す、PREFECTURE=東京都,神奈川県で都道府県を絞る）'
  task geocode: :environment do
    # ロケールがUTF-8でない環境では環境変数がバイナリとして届くため、UTF-8として読み直す
    prefectures = ENV['PREFECTURE'].to_s.dup.force_encoding(Encoding::UTF_8).split(/[,、]/).map(&:strip).compact_blank
    unknown = prefectures - Venue::PREFECTURES
    abort "都道府県の指定が正しくありません: #{unknown.join(', ')}（例: PREFECTURE=東京都）" if unknown.any?

    puts "対象の都道府県: #{prefectures.join(', ')}" if prefectures.any?
    counts = Venue.geocode_all(force: ENV['FORCE'].present?, prefectures: prefectures)
    puts "取得: #{counts[:geocoded]}件 / 見つからず: #{counts[:not_found]}件 / 失敗: #{counts[:failed]}件"
  end
end

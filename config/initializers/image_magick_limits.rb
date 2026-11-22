# frozen_string_literal: true

# Active Storage の縮小版（variant）は mini_magick 経由で ImageMagick を別プロセスとして起動して作る
# （config.active_storage.variant_processor = :mini_magick）。ImageMagick は画像全体を画素の配列として
# 読み込むため、画素数の大きい写真だと変換だけで数百MBを使い、512MB の本番インスタンスごと落ちていた
# （issue #2082。8000×6000 の JPEG で約 687MB）。
#
# ImageMagick は環境変数でメモリの上限を受け付け、超えた分は一時ファイルに逃がして処理を続ける
# （遅くはなるが落ちない。上の画像で約 117MB に収まる）。子プロセスは ENV を受け継ぐので、
# ここで未設定のときだけ既定値を入れる。Render の Environment などで設定すればそちらが優先される。
ENV['MAGICK_MEMORY_LIMIT'] ||= '64MiB'
ENV['MAGICK_MAP_LIMIT'] ||= '128MiB'

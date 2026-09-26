# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
# 1.1: デプロイ中に取得に失敗したCSS（404のHTML）がブラウザに残った問題への対応で、全アセットの
# URLを変えて取り直させるために変更（issue #1698）
#
# 環境変数 ASSETS_VERSION を設定すると、その値をコードの値の後ろにつなげる（例: "1.1-2"）。
# コードを触らずに全アセットのURLを変えて、利用者のブラウザ・CDNのキャッシュをリセットするための
# 非常用の手段。digestはビルド時（assets:precompile）に決まるため、Renderで値を変えるときは
# 「Save, rebuild, and deploy」を選ぶこと（再ビルドなしの再起動では変わらない）。
# 「大きい方を採用」ではなく「つなげる」形にしているのは、コードと環境変数のどちらを変えても
# 必ずURLが変わるようにするため。
Rails.application.config.assets.version = ['1.1', ENV['ASSETS_VERSION'].to_s.strip.presence].compact.join('-')

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
Rails.application.config.assets.paths << Rails.root.join('app/assets/builds')

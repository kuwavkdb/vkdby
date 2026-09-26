# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
# 1.1: デプロイ中に取得に失敗したCSS（404のHTML）がブラウザに残った問題への対応で、全アセットの
# URLを変えて取り直させるために変更（issue #1698）
Rails.application.config.assets.version = '1.1'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
Rails.application.config.assets.paths << Rails.root.join('app/assets/builds')

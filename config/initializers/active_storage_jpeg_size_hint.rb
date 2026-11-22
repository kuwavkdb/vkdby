# frozen_string_literal: true

# 大きな JPEG の縮小版を、読み込み段階で縮小して作る（issue #2088）。詳細は lib/active_storage_ext/jpeg_size_hint.rb
require Rails.root.join('lib/active_storage_ext/jpeg_size_hint').to_s

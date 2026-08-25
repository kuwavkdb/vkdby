# frozen_string_literal: true

# ActiveStorage::Analyzer::ImageAnalyzer::Vips#accept? はActiveStorage.variant_processorが
# :vipsであることを前提にしている（variant生成にvipsを使う設定でなければ画像解析にも
# 使われない）。本アプリはActiveStorageのvariant（サムネイル等）を一切生成しておらず
# （.variant()呼び出しなし）、variant_processorを:vipsへ切り替えると、
# libvipsが無い環境（開発機・CI等）でActiveStorage::Blob::Representable関連の
# 起動時requireが素通しのLoadErrorでアプリごと落ちてしまう（Rails 8.1の
# engine.rbのLoadErrorメッセージ判定が"image_processing"の大文字小文字違いで
# 拾いきれずraiseし直されるため）。
#
# そのため variant_processor は :mini_magick のままにし、画像解析
# （markdown本文内画像のwidth/height取得、issue #1215）だけvipsを使えるよう、
# variant_processorの値に関わらずacceptするサブクラスを用意して
# config.active_storage.analyzers の先頭に差し込む（config/application.rb参照）。
# vips本体（共有ライブラリ）が無い環境では、親クラス
# ActiveStorage::Analyzer::ImageAnalyzer::Vips が自前でrequire "ruby-vips"を
# LoadErrorごと安全にrescueしており（ActiveStorage::VIPS_AVAILABLE = false）、
# 解析時に空メタデータを返すだけでクラッシュしない。
module ActiveStorage
  class Analyzer::ImageAnalyzer::SafeVips < Analyzer::ImageAnalyzer::Vips
    def self.accept?(blob)
      Analyzer::ImageAnalyzer.accept?(blob)
    end
  end
end

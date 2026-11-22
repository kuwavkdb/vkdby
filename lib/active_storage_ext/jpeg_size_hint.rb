# frozen_string_literal: true

require 'active_storage/transformers/image_magick'

module ActiveStorageExt
  # Active Storage の縮小版（variant）を ImageMagick で作るとき、JPEG を読み込む段階で縮小させる
  # （-define jpeg:size=WxH、issue #2088）。
  #
  # ImageMagick は通常、JPEG を元の画素数のまま読み込んでから縮小するため、画素数の大きい写真では
  # 数百MBを使う（#2082）。jpeg:size を指定すると、指定以上の大きさを保てる範囲で 1/2・1/4・1/8 に
  # 縮めて読み込むので、メモリも時間も大きく減る（8000×6000 → 1200px 幅で 約687MB・2.0秒 → 約130MB・0.5秒）。
  # 指定した大きさより小さくは読み込まないため、仕上がりの画質は変わらない。JPEG 以外では無視される。
  #
  # image_processing は loader(define: ...) に対応しているが、Active Storage の variant の指定では
  # loader が許されていない（ActiveStorage.supported_image_processing_methods に無い）ため、
  # 変換処理（ActiveStorage::Transformers::ImageMagick#process）の読み込みの指定に足す。
  module JpegSizeHint
    # 縮小の指定。値は [幅, 高さ]（片方が nil のこともある）
    RESIZE_METHODS = %i[resize_to_limit resize_to_fit resize_to_fill resize_and_pad resize_to_cover].freeze
    # 目標の何倍の大きさで読み込むか。縮小の仕上がりを保つため、目標ちょうどではなく余裕を持たせる
    SCALE = 2

    private

    def process(file, format:)
      hint = jpeg_size_hint
      return super if hint.nil?

      processor
        .source(file)
        .loader(page: 0, define: { jpeg: { size: hint } })
        .convert(format)
        .apply(operations)
        .call
    end

    # 読み込みの大きさ（"WxH"）。縮小の指定が無いときは nil（Active Storage の既定の処理に任せる）。
    # 幅・高さの片方しか無いときは、もう片方にも同じ値を使う（縦長・横長のどちらでも目標を下回らないように）
    def jpeg_size_hint
      dimensions = transformations.find { |name, _| RESIZE_METHODS.include?(name.to_sym) }&.last
      return nil unless dimensions.is_a?(Array)

      sizes = dimensions.first(2).grep(Numeric).map { |value| (value * SCALE).ceil }
      return nil if sizes.empty?

      edge = sizes.max
      "#{edge}x#{edge}"
    end
  end
end

ActiveStorage::Transformers::ImageMagick.prepend(ActiveStorageExt::JpegSizeHint)

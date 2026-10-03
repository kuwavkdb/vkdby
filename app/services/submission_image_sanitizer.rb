# frozen_string_literal: true

# 公開の投稿フォーム（UnitSubmission）で受け付けた画像を、保存前に作り直す（issue #1718）。
#
# - 形式はファイルの中身（libvipsのローダー）で判定し、JPEG / PNG / WebP 以外は受け付けない。
#   ブラウザが送るContent-Typeや拡張子は偽装できるため使わない。GIF・SVGは対象外。
# - EXIF（撮影位置など）を含むメタデータをすべて取り除く。取り除く前にEXIFの向き情報を
#   画素に反映する（先に消すと写真が横倒しになるため）。
# - 長辺がMAX_DIMENSIONを超える画像は縮小する。Vips::Image.thumbnailは読み込み時に
#   縮小するため、大きな画像でもメモリを使いすぎない。
# - 長辺・品質は引数で変えられる。Unit作成時に使わなかった投稿画像を縮小して残すのにも使う
#   （UnitSubmissionImageTransfer、issue #1719）。
#
# libvipsが入っていない環境（開発機・CI等）では作り直せないため、Unavailableを投げる
# （メタデータを残したまま保存しないよう、呼び出し側では画像を受け付けない扱いにする）。
class SubmissionImageSanitizer
  class Error < StandardError; end
  class Unavailable < Error; end
  class UnsupportedImage < Error; end

  MAX_DIMENSION = 4000
  QUALITY = 90

  # libvipsのローダー名 => [保存時の拡張子, Content-Type, 品質を指定できるか]
  FORMATS = {
    'jpegload' => ['.jpg', 'image/jpeg', true],
    'pngload' => ['.png', 'image/png', false],
    'webpload' => ['.webp', 'image/webp', true]
  }.freeze

  Result = Data.define(:io, :filename, :content_type)

  # file は path を持つもの（アップロードされたファイルやTempfile）。保存時のファイル名は
  # filename（拡張子は無視する）、無ければ file.original_filename から作る
  def self.call(file, max_dimension: MAX_DIMENSION, quality: QUALITY, filename: nil)
    new(file, max_dimension:, quality:, filename:).call
  end

  # OgpImageGenerator.vips_available? と同じく、テストでstubできるようメソッド経由にしている
  def self.vips_available?
    ActiveStorage::VIPS_AVAILABLE
  end

  def initialize(file, max_dimension: MAX_DIMENSION, quality: QUALITY, filename: nil)
    @file = file
    @max_dimension = max_dimension
    @quality = quality
    @filename = filename
  end

  def call
    raise Unavailable, 'libvips is not available' unless self.class.vips_available?

    sanitize
  end

  private

  # libvipsが無い環境ではVips::Errorも定義されないため、rescueはこのメソッドに閉じ込める
  def sanitize
    extension, content_type, lossy = detect_format
    image = Vips::Image.thumbnail(@file.path, @max_dimension, height: @max_dimension, size: :down)
    save_options = lossy ? { Q: @quality } : {}
    buffer = image.write_to_buffer(extension, **save_options, **strip_options)

    Result.new(io: StringIO.new(buffer), filename: "#{basename}#{extension}", content_type:)
  rescue Vips::Error => e
    raise UnsupportedImage, e.message
  end

  # new_from_fileはヘッダーだけを読むので、ここで画素を展開することはない
  def detect_format
    loader = Vips::Image.new_from_file(@file.path).get('vips-loader')
    FORMATS.fetch(loader) { raise UnsupportedImage, "unsupported loader: #{loader}" }
  end

  # libvips 8.15 で strip は keep に置き換えられた（keep: 0 は VIPS_FOREIGN_KEEP_NONE）
  def strip_options
    Vips.at_least_libvips?(8, 15) ? { keep: 0 } : { strip: true }
  end

  def basename
    name = File.basename((@filename || @file.original_filename).to_s, '.*')
    name.presence || 'image'
  end
end

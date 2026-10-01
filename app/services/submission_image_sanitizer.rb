# frozen_string_literal: true

# 公開の投稿フォーム（UnitSubmission）で受け付けた画像を、保存前に作り直す（issue #1718）。
#
# - 形式はファイルの中身（libvipsのローダー）で判定し、JPEG / PNG / WebP 以外は受け付けない。
#   ブラウザが送るContent-Typeや拡張子は偽装できるため使わない。GIF・SVGは対象外。
# - EXIF（撮影位置など）を含むメタデータをすべて取り除く。取り除く前にEXIFの向き情報を
#   画素に反映する（先に消すと写真が横倒しになるため）。
# - 長辺がMAX_DIMENSIONを超える画像は縮小する。Vips::Image.thumbnailは読み込み時に
#   縮小するため、大きな画像でもメモリを使いすぎない。
#
# libvipsが入っていない環境（開発機・CI等）では作り直せないため、Unavailableを投げる
# （メタデータを残したまま保存しないよう、呼び出し側では画像を受け付けない扱いにする）。
class SubmissionImageSanitizer
  class Error < StandardError; end
  class Unavailable < Error; end
  class UnsupportedImage < Error; end

  MAX_DIMENSION = 4000

  # libvipsのローダー名 => [保存時の拡張子, Content-Type, 保存オプション]
  FORMATS = {
    'jpegload' => ['.jpg', 'image/jpeg', { Q: 90 }],
    'pngload' => ['.png', 'image/png', {}],
    'webpload' => ['.webp', 'image/webp', { Q: 90 }]
  }.freeze

  Result = Data.define(:io, :filename, :content_type)

  def self.call(file)
    new(file).call
  end

  # OgpImageGenerator.vips_available? と同じく、テストでstubできるようメソッド経由にしている
  def self.vips_available?
    ActiveStorage::VIPS_AVAILABLE
  end

  def initialize(file)
    @file = file
  end

  def call
    raise Unavailable, 'libvips is not available' unless self.class.vips_available?

    sanitize
  end

  private

  # libvipsが無い環境ではVips::Errorも定義されないため、rescueはこのメソッドに閉じ込める
  def sanitize
    extension, content_type, save_options = detect_format
    image = Vips::Image.thumbnail(@file.path, MAX_DIMENSION, height: MAX_DIMENSION, size: :down)
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
    name = File.basename(@file.original_filename.to_s, '.*')
    name.presence || 'image'
  end
end

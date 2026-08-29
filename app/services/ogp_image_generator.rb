# frozen_string_literal: true

# Unit/Person/CustomPageページのog:image/twitter:image用に、ユニット名・メンバー名・
# ページタイトルを合成したバナー画像（PNG）を生成する（issue #1259、CustomPage対応は#1263）。
#
# テンプレート画像（public/ogp_banner_template.png）は右下にロゴ・マスコットが
# 配置され、左側〜上部が名前を差し込むための余白になっているデザイン。サイズは1200x628
# （約1.91:1）で、X(Twitter)のsummary_large_imageカードが期待する比率に合わせてあり、
# SNS側でクロップされないようリサイズ・トリミングは不要（issue #1262。以前の
# 1500x500テンプレートは比率が合わずXで左右がクロップされていた）。
#
# 合成にはmini_magick/ImageMagick CLIではなくruby-vipsを使う。ImageMagick CLIは
# 本アプリの実行環境にインストールされていない（Gemfileのruby-vips導入時のコメント参照）ため。
#
# libvips本体（共有ライブラリ）が入っていない環境（開発機・CI等）でも
# アプリを落とさないよう、ActiveStorageのvips画像解析（lib/active_storage_ext/
# safe_vips_image_analyzer.rb）が定義する ActiveStorage::VIPS_AVAILABLE で
# ガードする。独自にrequire "ruby-vips"のrescueは行わない
# （config/application.rbでのanalyzer登録時に必ず読み込まれ、起動後は定義済みのため）。
class OgpImageGenerator
  # デフォルトのog:image（config.site_ogp_image_path）としてもこのファイルをそのまま使う
  # （public/配下に置くことで、名前入りバナー生成前の状態がサイト共通デフォルト画像になる）。
  TEMPLATE_PATH = Rails.root.join('public/ogp_banner_template.png').freeze

  # テンプレート画像内の、名前を差し込む黄色い余白部分の座標（サンプリングして決定。
  # ロゴ・マスコットが画像内で最も左に張り出す位置がx=895前後のため、50pxの余白を
  # 見込んでbox幅を800に設定している。heightは箱いっぱいに広げるとオートフィットが
  # 縦方向を優先してしまい行数が増えすぎる・文字が肥大化しすぎるため、280に抑えている）
  TEXT_BOX = { left: 50, top: 60, width: 800, height: 280 }.freeze

  # テンプレート内のロゴ・マスコットと同系統のネイビー（テンプレート画像からサンプリング）
  TEXT_COLOR = [20, 46, 108].freeze

  # 特定のシステムフォントを名指しせず、fontconfigの一般名（Sans Bold）に解決を委ねる。
  # 開発機（macOS）ではHiragino等に、本番（Docker、要fonts-noto-cjk）ではNoto Sans CJK JPに
  # 解決される想定。フォントファイルをリポジトリに同梱しない方針（ライセンス・肥大化回避）。
  FONT = 'Sans Bold'

  def self.call(name)
    new(name).call
  end

  # ActiveStorage::VIPS_AVAILABLE をそのまま参照するメソッド。テストでlibvips未導入環境を
  # 再現できるよう、定数参照ではなくstub可能なメソッド経由にしている。
  def self.vips_available?
    ActiveStorage::VIPS_AVAILABLE
  end

  def initialize(name)
    @name = name
  end

  # 生成できない場合（libvips未導入、フォント未解決による合成失敗等）はnilを返す。
  # 呼び出し側（OgpImageAttachable）はnilならデフォルト画像へのフォールバックを継続する。
  def call
    return nil unless self.class.vips_available?

    composed = compose_image
    composed.write_to_buffer('.png')
  rescue Vips::Error => e
    Rails.logger.error("OgpImageGenerator: 画像生成に失敗しました (#{@name.inspect}): #{e.message}")
    nil
  end

  private

  def compose_image
    base = Vips::Image.new_from_file(TEMPLATE_PATH.to_s)
    text_mask = Vips::Image.text(
      @name.to_s,
      font: FONT,
      width: TEXT_BOX[:width],
      height: TEXT_BOX[:height],
      align: :low
    )
    colored_text = text_mask.new_from_image(TEXT_COLOR).bandjoin(text_mask).copy(interpretation: :srgb)

    base.composite2(colored_text, :over, x: TEXT_BOX[:left], y: TEXT_BOX[:top])
  end
end

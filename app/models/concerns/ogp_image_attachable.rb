# frozen_string_literal: true

# Unit/Personのプロフィールページ用に、名前入りのog:image/twitter:imageをオンデマンドで
# 生成・キャッシュする（issue #1259）。CustomPage（`title`カラムを使用）にも対応（issue #1263）。
#
# 初回アクセス時（ogp_image_relative_url呼び出し時）にOgpImageGeneratorで画像を生成して
# ActiveStorageに添付し、以降は添付済みの画像をそのまま使い回す。テキストが変更されたら
# 次回アクセス時に再生成されるよう、更新コミット後に古い添付をpurgeする。
#
# 合成するテキストの取得元はUnit/Personの`name`カラムがデフォルト。`name`カラムを持たない
# モデル（CustomPageの`title`等）はinclude先で`ogp_image_attachable_text`と
# `ogp_image_attachable_text_changed?`をoverrideする。
#
# 添付（R2への書き込み）が失敗した場合、例外はrescueしてログに残し、デフォルト画像への
# フォールバックに委ねる（呼び出し元をエラーにしない）。また、失敗直後にFAILURE_COOLDOWN
# の間は再試行せず生成処理自体をスキップする。R2側の障害等でattachが失敗し続ける状況で、
# アクセスの度に重いvips処理を繰り返して負荷をかけ続けないようにするため（issue #1267）。
module OgpImageAttachable
  extend ActiveSupport::Concern

  FAILURE_COOLDOWN = 1.hour

  included do
    has_one_attached :ogp_image

    after_update_commit :purge_ogp_image, if: :ogp_image_attachable_text_changed?
  end

  # og:image用の相対URL。生成できなかった場合（libvips未導入等）はnilを返し、
  # 呼び出し側（app/views/profiles/show.html.erb等）はデフォルト画像へのフォールバックに任せる。
  def ogp_image_relative_url
    ensure_ogp_image!
    return nil unless ogp_image.attached?

    Rails.application.routes.url_helpers.rails_blob_path(ogp_image, only_path: true)
  end

  private

  # バナーに合成するテキスト。デフォルトはUnit/Person共通の`name`カラム。
  def ogp_image_attachable_text
    name
  end

  # 上記テキストが変更されたか（再生成のトリガー）。ogp_image_attachable_textをoverrideする
  # 場合は、対応するカラムの変更判定になるようこちらも合わせてoverrideすること。
  def ogp_image_attachable_text_changed?
    saved_change_to_name?
  end

  def ensure_ogp_image!
    return if ogp_image.attached?
    return if ogp_image_attach_recently_failed?

    png = OgpImageGenerator.call(ogp_image_attachable_text)
    return unless png

    attach_ogp_image(png)
  end

  def attach_ogp_image(png)
    ogp_image.attach(
      io: StringIO.new(png),
      filename: "ogp-#{self.class.name.underscore}-#{id}.png",
      content_type: 'image/png'
    )
  rescue StandardError => e
    Rails.logger.error(
      "OgpImageAttachable: 画像の添付に失敗しました (#{self.class.name}##{id}): #{e.class}: #{e.message}"
    )
    mark_ogp_image_attach_failed
  end

  def purge_ogp_image
    ogp_image.purge_later
  end

  def ogp_image_attach_recently_failed?
    Rails.cache.exist?(ogp_image_attach_failure_cache_key)
  end

  def mark_ogp_image_attach_failed
    Rails.cache.write(ogp_image_attach_failure_cache_key, true, expires_in: FAILURE_COOLDOWN)
  end

  def ogp_image_attach_failure_cache_key
    "ogp_image_attach_failure/#{self.class.name}/#{id}"
  end
end

# frozen_string_literal: true

# Unit/Personのプロフィールページ用に、名前入りのog:image/twitter:imageをオンデマンドで
# 生成・キャッシュする（issue #1259）。
#
# 初回アクセス時（ogp_image_relative_url呼び出し時）にOgpImageGeneratorで画像を生成して
# ActiveStorageに添付し、以降は添付済みの画像をそのまま使い回す。名前が変更されたら
# 次回アクセス時に再生成されるよう、更新コミット後に古い添付をpurgeする。
module OgpImageAttachable
  extend ActiveSupport::Concern

  included do
    has_one_attached :ogp_image

    after_update_commit :purge_ogp_image, if: :saved_change_to_name?
  end

  # og:image用の相対URL。生成できなかった場合（libvips未導入等）はnilを返し、
  # 呼び出し側（app/views/profiles/show.html.erb）はデフォルト画像へのフォールバックに任せる。
  def ogp_image_relative_url
    ensure_ogp_image!
    return nil unless ogp_image.attached?

    Rails.application.routes.url_helpers.rails_blob_path(ogp_image, only_path: true)
  end

  private

  def ensure_ogp_image!
    return if ogp_image.attached?

    png = OgpImageGenerator.call(name)
    return unless png

    ogp_image.attach(
      io: StringIO.new(png),
      filename: "ogp-#{self.class.name.underscore}-#{id}.png",
      content_type: 'image/png'
    )
  end

  def purge_ogp_image
    ogp_image.purge_later
  end
end

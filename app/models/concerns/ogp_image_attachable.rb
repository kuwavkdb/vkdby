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
#
# ActiveStorageは添付先レコードへのattach/purgeのたびにレコード自体をtouchする仕様のため
# （belongs_to :record, touch: true）、対策をしないとOGP画像の遅延生成・自動再生成が走る
# だけで対象レコードのupdated_atが書き換わってしまう。ページ閲覧（クローラー等含む）だけで
# トップページサイドバーの「最近の更新」に、実際には編集していないページが浮上する不具合の
# 原因になっていた（issue #1528）。ここではattach/purge直後にupdated_atを元の値へ戻すことで、
# 「本当にコンテンツを編集した時刻」だけがupdated_atに反映されるようにする。
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
    original_updated_at = updated_at

    ogp_image.attach(
      io: StringIO.new(png),
      filename: "ogp-#{self.class.name.underscore}-#{id}.png",
      content_type: 'image/png'
    )

    return if ogp_image.attached? && ogp_image.attachment.persisted?

    # ActiveStorage::Attached::One#attachは、永続化済みレコードに対しては内部で
    # レコード自体をsaveする。このsaveがバリデーションエラー等で失敗した場合、attachは
    # 例外を投げずに添付前の状態へ戻さないため、ogp_imageはメモリ上「添付済み」のまま
    # 実体（blob/attachment）が保存されない不整合な状態になる（issue #1473）。
    # 放置するとogp_image_relative_url側でsigned_id取得時にArgumentErrorが発生し
    # 500エラーになるため、ここで検知してレコードをreloadし添付前の状態に戻す。
    save_error_messages = errors.full_messages.presence
    reload
    Rails.logger.error(
      "OgpImageAttachable: 画像の添付に失敗しました (#{self.class.name}##{id}): " \
      "レコードの保存に失敗しました #{save_error_messages}"
    )
    mark_ogp_image_attach_failed
  rescue StandardError => e
    Rails.logger.error(
      "OgpImageAttachable: 画像の添付に失敗しました (#{self.class.name}##{id}): #{e.class}: #{e.message}"
    )
    mark_ogp_image_attach_failed
  ensure
    restore_updated_at(original_updated_at)
  end

  def purge_ogp_image
    original_updated_at = updated_at
    ogp_image.purge_later
  ensure
    restore_updated_at(original_updated_at)
  end

  # OGP画像のattach/purgeが伴うActiveStorageのtouch（issue #1528）を打ち消し、
  # updated_atを実際の編集操作時点の値に戻す。update_columnはコールバックを発火しない
  # ため、after_update_commit :purge_ogp_imageとの再帰は起きない。
  def restore_updated_at(original_updated_at)
    return unless persisted?
    return if updated_at == original_updated_at

    update_column(:updated_at, original_updated_at)
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

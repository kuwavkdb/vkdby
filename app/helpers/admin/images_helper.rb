# frozen_string_literal: true

module Admin
  module ImagesHelper
    # 一覧のサムネイルは aspect-square のグリッドで表示するだけなので、
    # 元画像ではなくリサイズした variant を使い表示速度を改善する（issue #1632）。
    # 画像として解析できない添付（解析失敗・非対応フォーマット等）は
    # variant生成に失敗する可能性があるため、その場合は元画像にフォールバックする。
    THUMBNAIL_SIZE = [200, 200].freeze

    def admin_image_thumbnail_source(attachment)
      return url_for(attachment) unless attachment.representable?

      attachment.variant(resize_to_limit: THUMBNAIL_SIZE)
    end
  end
end

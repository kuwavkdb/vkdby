# frozen_string_literal: true

module Admin
  module ItemsHelper
    # 一括アーティスト差し替えフォームのDOM id。
    # 行内の「論理削除」ボタン(button_to)が独自の<form>を生成するため、この一括差し替え用の
    # <form>とItemの一覧テーブルは別々に描画し、チェックボックス側から form="#{BULK_ARTIST_UPDATE_FORM_ID}"
    # 属性で論理的に紐付けている(<form>を入れ子にしない)。詳細は index.html.erb のコメント参照。
    BULK_ARTIST_UPDATE_FORM_ID = 'bulk-artist-update-form'
  end
end

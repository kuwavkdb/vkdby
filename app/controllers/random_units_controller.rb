# frozen_string_literal: true

# 公開中のバンドからランダムに1件を選び、そのページへリダイレクトする（issue #2124）。
# ステータスでは絞らず、解散済み・活動休止中のバンドも対象にする。
class RandomUnitsController < ApplicationController
  def show
    # 毎回違うバンドを返すため、ブラウザや CDN にリダイレクトをキャッシュさせない
    no_store
    key = Unit.for_index.published.band.order(Arel.sql('RANDOM()')).pick(:key)
    redirect_to key ? profile_path(key) : units_path
  end
end

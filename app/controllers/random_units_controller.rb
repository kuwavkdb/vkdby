# frozen_string_literal: true

# 公開中のバンドからランダムに1件を選び、そのページへリダイレクトする（issue #2124）。
# ステータスでは絞らず、解散済み・活動休止中のバンドも対象にする。
class RandomUnitsController < ApplicationController
  # 対象バンドの key の一覧をキャッシュしておく時間。アクセスのたびに全件を読んで
  # 並べ替えないよう、一覧はこの間隔で作り直し、1件はRuby側で選ぶ
  BAND_KEYS_CACHE_KEY = 'random_units/band_keys'
  BAND_KEYS_CACHE_TTL = 5.minutes

  def show
    # 毎回違うバンドを返すため、ブラウザや CDN にリダイレクトをキャッシュさせない
    no_store
    key = band_keys.sample
    redirect_to key ? profile_path(key) : units_path
  end

  private

  def band_keys
    Rails.cache.fetch(BAND_KEYS_CACHE_KEY, expires_in: BAND_KEYS_CACHE_TTL, race_condition_ttl: 10.seconds) do
      Unit.for_index.published.band.pluck(:key)
    end
  end
end

# frozen_string_literal: true

# 年指定なしの日付ページ（/date/-/:month/:day）の og:image（issue #1746）。
# 「今日は何の日？／M月D日」をテンプレート画像に合成した PNG を返す。
# 日付ページはモデルを持たず、月日（366通り）ごとに内容が決まるため Active Storage には保存せず、
# アクセス時にその場で生成し、長期の Cache-Control で Cloudflare・ブラウザのキャッシュに任せる。
# ページ本体ではないため、ApplicationController（allow_browser・フッター読み込み等）は通さない
class OnThisDayOgpImagesController < ActionController::Base
  CACHE_DURATION = 30.days
  # 画像の文言を変えたら上げる。og:image のURLに ?v= として付け、長期キャッシュを無効にする
  # （2: 「なんの日」→「何の日」、issue #1753）
  VERSION = 2

  def show
    date = Date.new(2000, params[:month].to_i, params[:day].to_i)
    png = OgpImageGenerator.call("今日は何の日？\n#{date.month}月#{date.day}日")
    # libvips 未導入等で生成できない環境では、サイト共通のデフォルト画像に任せる
    return redirect_to Rails.application.config.site_ogp_image_path unless png

    expires_in CACHE_DURATION, public: true
    send_data png, type: 'image/png', disposition: 'inline'
  rescue Date::Error
    head :not_found
  end
end

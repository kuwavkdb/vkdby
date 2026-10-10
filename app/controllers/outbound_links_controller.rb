# frozen_string_literal: true

# 外部サイトへ遷移する前に挟むクッションページ（issue #1823）。
# オープンリダイレクトを作らないよう、遷移先URLはリクエストから受け取らず、
# 対象のレコードからサーバー側で引く。対象を増やすときはアクションを追加し、
# @destination_url を ExternalUrl.sanitize を通した値にして show を描画する。
class OutboundLinksController < ApplicationController
  def item
    @item = Item.kept.find(params[:id])
    @destination_url = ExternalUrl.sanitize(@item.display_link_url)
    raise ActiveRecord::RecordNotFound if @destination_url.nil?

    @destination_host = ExternalUrl.display_host(@destination_url)
    render :show
  end
end

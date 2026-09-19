# frozen_string_literal: true

class CustomPagesController < ApplicationController
  include SidebarLoadable

  before_action :load_sidebar_data

  def show
    # with_attached_ogp_image: ogp_image_relative_url内のattached?判定が毎アクセスN+1で
    # クエリを発行しないよう、attachment/blobを事前にeager loadしておく（issue #1267）。
    @page = CustomPage.published.with_attached_ogp_image.find_by!(key: params[:key])
  rescue ActiveRecord::RecordNotFound
    render_not_found(query: params[:key])
  end

  def index_page
    @page = CustomPage.published.with_attached_ogp_image.find_by!(key: 'index')
    # ルート('/')としての表示であることをビューに伝えるフラグ。/pages/index経由（showアクション）で
    # 同じページを開いた場合は通常のカスタムページと同様に表示するため、@page.keyではなく
    # アクション（ルートかどうか）で判定する（issue #1383）。
    @root_page = true
    render :show
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end
end

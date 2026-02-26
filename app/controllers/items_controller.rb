# frozen_string_literal: true

class ItemsController < ApplicationController
  def index
    # 基本となるスコープの作成
    base_scope = Item.all
    if params[:old_key].present?
      @artist = Unit.find_by(old_key: params[:old_key]) || Person.find_by(old_key: params[:old_key])
      base_scope = base_scope.by_artist_old_key(params[:old_key])
    end

    # 年月タブ用のカウント取得（アーティスト絞り込みがある場合はそれに限定）
    dates = base_scope.pluck(:release_date)
    @year_counts = dates.map(&:year).tally
    @years = @year_counts.keys.sort.reverse

    # 最終的な表示スコープの構築
    scope = base_scope.order(release_date: :desc)

    if params[:year].present?
      year = params[:year].to_i
      month = params[:month].presence&.to_i

      target_dates = dates.select { |d| d.year == year }
      @month_counts = target_dates.map(&:month).tally
      @months = @month_counts.keys.sort.reverse

      start_date = Date.new(year, month || 1, 1)
      end_date = month ? start_date.end_of_month : start_date.end_of_year

      scope = scope.where(release_date: start_date..end_date)
    end

    @pagy, @items = pagy(scope, limit: 20)
  end

  def show
    @item = Item.find_by!(asin: params[:asin])

    # artistsのjsonbからold_keyを使用して関連するアーティスト(PersonまたはUnit)を読み込み
    @artists = @item.artists.filter_map do |artist_data|
      next unless artist_data['old_key'].present?

      Unit.find_by(old_key: artist_data['old_key']) ||
        Person.find_by(old_key: artist_data['old_key'])
    end

    # 同じアーティストの関連アイテムを検索
    @related_items = if @item.artists.any? { |a| a['old_key'].present? }
                       Item.where.not(id: @item.id)
                           .by_artist_old_key(@item.artists.first['old_key'])
                           .order(release_date: :desc)
                           .limit(6)
                     else
                       Item.none
                     end

    respond_to do |format|
      format.html
      format.json { render json: @item }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html do
        render file: Rails.root.join('public/404.html'), status: :not_found, layout: false
      end
      format.json { render json: { error: 'Item not found' }, status: :not_found }
    end
  end
end

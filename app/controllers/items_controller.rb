# frozen_string_literal: true

class ItemsController < ApplicationController
  def show
    @item = Item.find(params[:id])

    scopes = @item.artists.flat_map do |a|
      [
        (Item.by_artist_key(a['key']) if a['key'].present?),
        (Item.by_artist_old_key(a['old_key']) if a['old_key'].present?),
        (Item.by_artist_name(a['name']) if a['name'].present?)
      ].compact
    end

    @related_items = if scopes.any?
                       scopes.reduce(:or).where.not(id: @item.id).order(Arel.sql('RANDOM()')).limit(10)
                     else
                       Item.none
                     end
  end

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
end

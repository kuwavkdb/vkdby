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

    if scopes.any?
      base_query = scopes.reduce(:or).where.not(id: @item.id)
      @related_items_count = base_query.count
      @related_items = base_query.order(Arel.sql('RANDOM()')).limit(10)
    else
      @related_items_count = 0
      @related_items = Item.none
    end
  end

  def index
    # 基本となるスコープの作成
    base_scope = Item.all
    if params[:old_key].present?
      @artist = Unit.find_by(old_key: params[:old_key]) || Person.find_by(old_key: params[:old_key])
      scopes = [Item.by_artist_old_key(params[:old_key])]
      scopes << Item.by_artist_key(@artist.key) if @artist&.key.present?
      base_scope = base_scope.merge(scopes.reduce(:or))
    elsif params[:key].present?
      @artist = Unit.find_by(key: params[:key]) || Person.find_by(key: params[:key])
      scopes = [Item.by_artist_key(params[:key])]
      scopes << Item.by_artist_old_key(@artist.old_key) if @artist&.old_key.present?
      base_scope = base_scope.merge(scopes.reduce(:or))
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

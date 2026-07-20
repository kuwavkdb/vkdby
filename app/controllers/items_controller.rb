# frozen_string_literal: true

class ItemsController < ApplicationController
  def show
    @item = Item.find(params[:id])

    scoped_artists = @item.artists.filter_map { |a| [a, artist_item_scope(a)] if artist_item_scope(a) }

    if scoped_artists.any?
      base_query = scoped_artists.map(&:last).reduce(:or).where.not(id: @item.id)
      @related_items = base_query.order(Arel.sql('RANDOM()')).limit(10)
    else
      @related_items = Item.none
    end

    # アーティストごとに「もっと見る」ボタンを出す必要があるかを判定する
    # (関連作品グリッドは全アーティストのOR結果からのランダム抽出なので、
    #  特定の1人だけの作品数が多くても網羅されているとは限らないため)
    @artists_with_more_items = scoped_artists.filter_map do |a, scope|
      a if scope.where.not(id: @item.id).count > 10
    end
  end

  def index
    base_scope = filter_by_artist(Item.all)
    base_scope = filter_by_query(base_scope)

    @year_counts = base_scope.where.not(release_date: nil)
                             .group('EXTRACT(year FROM release_date)::integer').count
    @years = @year_counts.keys.sort.reverse

    scope = base_scope.order(release_date: :desc)
    if params[:decade].present?
      scope = filter_by_decade(scope)
    elsif params[:year].present?
      scope = filter_by_year(scope, base_scope)
    end

    @pagy, @items = pagy(scope, limit: 20)
  end

  private

  # key/old_keyが分かっているアーティストはそれらのみで一致を判定する。
  # nameは表記揺れがなく一意なサイト内ページ識別子ではない
  # (例: 「オムニバス」は多数の無関係な作品で使われる汎用的な名前)ため、
  # key/old_keyが無い(サイト内にページが存在しない)場合のみnameでの一致にフォールバックする。
  def artist_item_scope(artist)
    if artist['key'].present? || artist['old_key'].present?
      scopes = [
        (Item.by_artist_key(artist['key']) if artist['key'].present?),
        (Item.by_artist_old_key(artist['old_key']) if artist['old_key'].present?)
      ].compact
      scopes.reduce(:or)
    elsif artist['name'].present?
      Item.by_artist_name(artist['name'])
    end
  end

  def filter_by_artist(scope)
    if params[:old_key].present?
      @artist = Unit.kept.find_by(old_key: params[:old_key]) || Person.kept.find_by(old_key: params[:old_key])
      scopes = [Item.by_artist_old_key(params[:old_key])]
      scopes << Item.by_artist_key(@artist.key) if @artist&.key.present?
      scope.merge(scopes.reduce(:or))
    elsif params[:key].present?
      @artist = Unit.kept.find_by(key: params[:key]) || Person.kept.find_by(key: params[:key])
      scopes = [Item.by_artist_key(params[:key])]
      scopes << Item.by_artist_old_key(@artist.old_key) if @artist&.old_key.present?
      scope.merge(scopes.reduce(:or))
    else
      scope
    end
  end

  def filter_by_query(scope)
    return scope if params[:q].blank?

    scope.where('title ILIKE :q OR artists::text ILIKE :q', q: "%#{params[:q]}%")
  end

  def filter_by_decade(scope)
    decade = params[:decade].to_i
    scope.where(release_date: Date.new(decade, 1, 1)..Date.new(decade + 9, 12, 31))
  end

  def filter_by_year(scope, base_scope)
    year = params[:year].to_i
    month = params[:month].presence&.to_i

    @month_counts = base_scope.where('EXTRACT(year FROM release_date) = ?', year)
                              .group('EXTRACT(month FROM release_date)::integer').count
    @months = @month_counts.keys.sort.reverse

    start_date = Date.new(year, month || 1, 1)
    end_date = month ? start_date.end_of_month : start_date.end_of_year
    scope.where(release_date: start_date..end_date)
  end
end

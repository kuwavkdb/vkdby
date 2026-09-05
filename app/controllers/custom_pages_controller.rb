# frozen_string_literal: true

class CustomPagesController < ApplicationController
  before_action :load_sidebar_data

  NEW_RELEASES_LIMIT = 5
  # Item#expire_new_releases_sidebar_cacheから商品登録時のキャッシュクリアにも使う
  NEW_RELEASES_CACHE_KEY_PREFIX = 'sidebar/new_releases'

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

  private

  def load_sidebar_data
    today = Date.current
    ttl = Time.current.end_of_day - Time.current

    load_new_releases(today, ttl)
    load_recent_trends(today, ttl)

    @recently_updated = Rails.cache.fetch('sidebar/recently_updated', expires_in: 10.minutes) do
      pages   = CustomPage.published.order(updated_at: :desc).limit(10).to_a
      units   = Unit.kept.published.where.not(key: nil).order(updated_at: :desc).limit(10).to_a
      persons = Person.kept.published.where.not(key: nil).order(updated_at: :desc).limit(10).to_a
      (pages + units + persons).sort_by(&:updated_at).reverse.first(8)
    end

    @birthday_people = Rails.cache.fetch("sidebar/birthday_people/#{today}", expires_in: ttl) do
      Person.kept.published.birthday_on(today).or(Person.kept.published.birthday_on(today + 1)).order(:name_kana).to_a
    end
  end

  # 当日前後5日間に発売されたアイテムをサイドバー表示用に抽出する。
  # 対象期間の件数が多くなりうるため、商品バリエーションを保つ目的で
  # 同一アーティスト（key/old_key/nameのいずれかが一致）の商品は発売日が早い方のみを採用し、
  # 最大NEW_RELEASES_LIMIT件まで表示する。
  def load_new_releases(today, ttl)
    @new_releases = Rails.cache.fetch("#{NEW_RELEASES_CACHE_KEY_PREFIX}/#{today}", expires_in: ttl) do
      candidates = Item.kept.where(release_date: (today - 5)..(today + 5)).order(:release_date).to_a
      used_artist_identities = Set.new
      picked = []

      candidates.each do |item|
        break if picked.size >= NEW_RELEASES_LIMIT

        identities = item.artists.to_a.filter_map { |a| a['key'].presence || a['old_key'].presence || a['name'].presence }
        next if identities.any? { |identity| used_artist_identities.include?(identity) }

        picked << item
        used_artist_identities.merge(identities)
      end

      picked
    end
  end

  def load_recent_trends(today, ttl)
    @weekly_trends = Rails.cache.fetch("sidebar/weekly_trends/#{today}", expires_in: ttl) do
      from_today = Trend.where(date: today..).order(date: :asc).limit(5).to_a
      recent     = Trend.where(date: (today - 2)..(today - 1)).order(date: :desc).limit(5).to_a
      (from_today + recent).sort_by(&:date).reverse
    end

    unit_ids   = @weekly_trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
    person_ids = @weekly_trends.flat_map { |t| t.people&.map { |p| p['person_id'] } }.compact.uniq
    @weekly_trend_units  = Unit.kept.where(id: unit_ids).index_by(&:id)
    @weekly_trend_people = Person.kept.where(id: person_ids).index_by(&:id)
  end
end

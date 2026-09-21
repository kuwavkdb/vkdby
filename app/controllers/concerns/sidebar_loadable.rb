# frozen_string_literal: true

# 全ページ共通のサイドバー（New Releases / Recent Trends / Recent Updates / Birthdays）用データを
# 読み込む。CustomPagesController・ProfilesController から include して使う（issue #1570）。
module SidebarLoadable
  extend ActiveSupport::Concern

  NEW_RELEASES_LIMIT = 5
  # Item#expire_new_releases_sidebar_cacheから商品登録時のキャッシュクリアにも使う
  NEW_RELEASES_CACHE_KEY_PREFIX = 'sidebar/new_releases'
  # キャッシュ失効直後にProfilesページへのアクセスが集中しても、再生成クエリが
  # 同時に何本も走らないよう、失効後この秒数は古い値を返しつつ1リクエストのみ
  # 再生成させる（redis_cache_storeのrace_condition_ttl。issue #1602）
  RACE_CONDITION_TTL = 10.seconds

  # Unit/Person/CustomPage#expire_sidebar_cacheからキャッシュクリアにも使う。
  # キャッシュする値の形（ActiveRecordオブジェクト→RecentlyUpdatedEntry構造体）を
  # 変更した際に、ローリングデプロイ中の新旧コード混在で形状不一致が起きないよう
  # バージョンサフィックスを付ける（issue #1603）
  RECENTLY_UPDATED_CACHE_KEY = 'sidebar/recently_updated/v2'

  # 最終的に表示するRecent Updatesの件数
  RECENTLY_UPDATED_LIMIT = 8
  # 各モデルから取得する件数の上限（8件全てが1モデルに偏るケースを考慮し、
  # RECENTLY_UPDATED_LIMITと同数まで取得すれば十分）
  RECENTLY_UPDATED_PER_MODEL_LIMIT = RECENTLY_UPDATED_LIMIT

  # サイドバーのRecent Updatesで表示するために必要な属性のみを持つ軽量な構造体（issue #1603）。
  # ActiveRecordオブジェクトを丸ごとキャッシュするとMarshalシリアライズのコストが大きいため、
  # 表示に使うカラムのみに絞り込んでキャッシュする。
  RecentlyUpdatedEntry = Struct.new(:type, :key, :label, :updated_at, keyword_init: true) do
    def path
      type == :custom_page ? Rails.application.routes.url_helpers.custom_page_path(key) : Rails.application.routes.url_helpers.profile_path(key)
    end
  end

  private

  def load_sidebar_data
    today = Date.current
    ttl = Time.current.end_of_day - Time.current

    load_new_releases(today, ttl)
    load_recent_trends(today, ttl)

    @recently_updated = Rails.cache.fetch(RECENTLY_UPDATED_CACHE_KEY, expires_in: 10.minutes) do
      pages   = recently_updated_entries(CustomPage.published, :custom_page, :title)
      units   = recently_updated_entries(Unit.kept.published.where.not(key: nil), :unit, :name)
      persons = recently_updated_entries(Person.kept.published.where.not(key: nil), :person, :name)

      (pages + units + persons).sort_by(&:updated_at).reverse.first(RECENTLY_UPDATED_LIMIT)
    end

    @birthday_people = Rails.cache.fetch("sidebar/birthday_people/#{today}", expires_in: ttl, race_condition_ttl: RACE_CONDITION_TTL) do
      Person.kept.published.birthday_on(today).or(Person.kept.published.birthday_on(today + 1)).order(:name_kana).to_a
    end
  end

  # `pluck`でカラムを絞り込んで取得し、表示に必要な属性のみを持つ軽量な構造体に詰め直す。
  # label_columnはCustomPageなら:title、Unit/Personなら:name。Unit/Personの`name`は
  # モデル側でCGI.unescapeHTMLするoverrideが入っているため、ここでも同様の処理を行う。
  def recently_updated_entries(relation, type, label_column)
    relation.order(updated_at: :desc).limit(RECENTLY_UPDATED_PER_MODEL_LIMIT).pluck(:key, label_column, :updated_at).map do |key, label, updated_at|
      label = CGI.unescapeHTML(label.to_s).presence unless type == :custom_page
      RecentlyUpdatedEntry.new(type:, key:, label:, updated_at:)
    end
  end

  # 当日前後5日間に発売されたアイテムをサイドバー表示用に抽出する。
  # 対象期間の件数が多くなりうるため、商品バリエーションを保つ目的で
  # 同一アーティスト（key/old_key/nameのいずれかが一致）の商品は発売日が早い方のみを採用し、
  # 最大NEW_RELEASES_LIMIT件まで表示する。
  def load_new_releases(today, ttl)
    @new_releases = Rails.cache.fetch("#{NEW_RELEASES_CACHE_KEY_PREFIX}/#{today}", expires_in: ttl, race_condition_ttl: RACE_CONDITION_TTL) do
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
    @weekly_trends = Rails.cache.fetch("sidebar/weekly_trends/#{today}", expires_in: ttl, race_condition_ttl: RACE_CONDITION_TTL) do
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

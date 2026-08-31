# frozen_string_literal: true

# == Schema Information
#
# Table name: items
#
#  id              :bigint           not null, primary key
#  artists         :jsonb            not null
#  asin            :string
#  discarded_at    :datetime
#  image_url       :string
#  link_url        :string           not null
#  release_date    :date             not null
#  title           :string           not null
#  various_artists :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  old_item_id     :integer
#
# Indexes
#
#  index_items_on_artists       (artists) USING gin
#  index_items_on_artists_trgm  (((artists)::text) gin_trgm_ops) USING gin
#  index_items_on_asin          (asin) UNIQUE
#  index_items_on_discarded_at  (discarded_at)
#  index_items_on_link_url      (link_url) UNIQUE
#  index_items_on_release_date  (release_date)
#  index_items_on_title         (title)
#  index_items_on_title_trgm    (title) USING gin
#
class Item < ApplicationRecord
  include Discard::Model

  validates :title, presence: true
  validates :release_date, presence: true
  validates :link_url, presence: true, uniqueness: true
  validates :asin, uniqueness: true, allow_blank: true

  after_commit :expire_new_releases_sidebar_cache

  # 出力用のURL。DBのlink_urlに現在のAmazonアソシエイトタグが含まれていない場合は、
  # asinから現在のタグ込みのURLを組み立てて返す（管理画面から手動登録された、
  # タグ抜きのURL等をカバーするため。issue #1304）
  def display_link_url
    return link_url if link_url.blank?
    return link_url if link_url.include?("/#{Rails.application.config.amazon_associate_tag}/")

    AmazonUrlBuilder.build(asin).presence || link_url
  end

  def artists_for_form
    require 'ostruct'
    entries = (self[:artists] || []).map { |a| ::OpenStruct.new(a) }
    3.times { entries << ::OpenStruct.new(name: '', old_key: '', key: '') }
    entries
  end

  # old_key でアーティストを検索するスコープ
  scope :by_artist_old_key, lambda { |old_key|
    where('artists @> ?', [{ old_key: old_key }].to_json)
  }

  # key でアーティストを検索するスコープ
  scope :by_artist_key, lambda { |key|
    where('artists @> ?', [{ key: key }].to_json)
  }

  # name でアーティストを検索するスコープ
  scope :by_artist_name, lambda { |name|
    where('artists @> ?', [{ name: name }].to_json)
  }

  # alias（表示名）でアーティストを検索するスコープ
  scope :by_artist_alias, lambda { |alias_name|
    where('artists @> ?', [{ alias: alias_name }].to_json)
  }

  # match_type ("old_key" / "key" / "name" / "alias") で一致した artists 要素を
  # replacement（{"name" =>, "key" =>, "old_key" =>, "alias" =>} を持つ Hash）で一括差し替えする。
  # alias は replacement の値で上書きする（未指定・空なら表示名は設定しない。既存の alias は引き継がれない）。
  # 一致する要素が無かった場合は何も更新せず false を返す（意図しない updated_at 更新を避けるため）。
  def replace_artist!(match_type:, match_value:, replacement:)
    return false unless %w[old_key key name alias].include?(match_type.to_s)

    new_artists = (artists || []).map do |entry|
      next entry unless entry[match_type.to_s].to_s == match_value.to_s

      entry.merge(
        'name' => replacement['name'],
        'key' => replacement['key'],
        'old_key' => replacement['old_key'],
        'alias' => replacement['alias'],
        'confirmed' => true
      ).compact_blank
    end

    return false if new_artists == artists

    update!(artists: new_artists)
    true
  end

  # 発売日で検索するスコープ
  scope :released_on, ->(date) { where(release_date: date) }
  scope :released_on_month_day, lambda { |month, day|
    where('EXTRACT(MONTH FROM release_date) = ? AND EXTRACT(DAY FROM release_date) = ?', month, day)
  }

  private

  # 新規登録・更新・削除(discard/undiscard含む)のたびに当日分のサイドバーキャッシュを破棄し、
  # 反映を待たせないようにする（issue #1297）
  def expire_new_releases_sidebar_cache
    Rails.cache.delete("#{CustomPagesController::NEW_RELEASES_CACHE_KEY_PREFIX}/#{Date.current}")
  end
end

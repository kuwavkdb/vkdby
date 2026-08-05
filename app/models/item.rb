# frozen_string_literal: true

# == Schema Information
#
# Table name: items
#
#  id              :bigint           not null, primary key
#  artists         :jsonb            not null
#  asin            :string
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
#  index_items_on_link_url      (link_url) UNIQUE
#  index_items_on_release_date  (release_date)
#  index_items_on_title         (title)
#  index_items_on_title_trgm    (title) USING gin
#
class Item < ApplicationRecord
  validates :title, presence: true
  validates :release_date, presence: true
  validates :link_url, presence: true, uniqueness: true
  validates :asin, uniqueness: true, allow_blank: true

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

  # match_type ("old_key" / "key" / "name") で一致した artists 要素を
  # replacement（{"name" =>, "key" =>, "old_key" =>} を持つ Hash）で一括差し替えする。
  # 一致する要素が無かった場合は何も更新せず false を返す（意図しない updated_at 更新を避けるため）。
  def replace_artist!(match_type:, match_value:, replacement:)
    return false unless %w[old_key key name].include?(match_type.to_s)

    new_artists = (artists || []).map do |entry|
      next entry unless entry[match_type.to_s].to_s == match_value.to_s

      entry.merge(
        'name' => replacement['name'],
        'key' => replacement['key'],
        'old_key' => replacement['old_key'],
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
end

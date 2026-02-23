# frozen_string_literal: true

# == Schema Information
#
# Table name: items
#
#  id           :bigint           not null, primary key
#  artists      :jsonb            not null
#  asin         :string
#  image_url    :string
#  link_url     :string           not null
#  release_date :date             not null
#  title        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  old_item_id  :integer
#
# Indexes
#
#  index_items_on_artists       (artists) USING gin
#  index_items_on_asin          (asin) UNIQUE
#  index_items_on_link_url      (link_url) UNIQUE
#  index_items_on_release_date  (release_date)
#  index_items_on_title         (title)
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

  # 発売日で検索するスコープ
  scope :released_on, ->(date) { where(release_date: date) }
  scope :released_on_month_day, lambda { |month, day|
    where('EXTRACT(MONTH FROM release_date) = ? AND EXTRACT(DAY FROM release_date) = ?', month, day)
  }
end

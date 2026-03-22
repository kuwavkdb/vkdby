# frozen_string_literal: true

# == Schema Information
#
# Table name: people
#
#  id            :bigint           not null, primary key
#  birth_year    :integer
#  birthday      :date
#  blood         :string
#  hometown      :string
#  key           :string
#  name          :string
#  name_kana     :string
#  name_log      :jsonb
#  note          :text
#  old_history   :text
#  old_key       :string
#  old_wiki_text :text
#  parts         :json
#  status        :integer          default("active"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  old_wiki_id   :integer
#
# Indexes
#
#  index_people_on_key        (key) UNIQUE
#  index_people_on_name       (name)
#  index_people_on_name_kana  (name_kana)
#  index_people_on_old_key    (old_key) UNIQUE
#
require 'cgi'
require 'discard'

class Person < ApplicationRecord
  include Discard::Model
  include WikiParser
  has_many :links, as: :linkable, dependent: :destroy
  has_many :unit_people
  has_many :units, through: :unit_people
  has_many :person_logs
  has_many :tag_index_items, as: :indexable, dependent: :destroy
  has_many :tag_indices, through: :tag_index_items
  has_many :sections, as: :sectionable, dependent: :destroy
  has_many :snapshot_people

  accepts_nested_attributes_for :links, allow_destroy: true, reject_if: proc { |attrs| attrs['url'].blank? }

  enum :status, { pre: 0, active: 1, free: 2, hiatus: 3, retirement: 90, passed_away: 98, unknown: 99 }

  # Valid parts for a person
  AVAILABLE_PARTS = %w[vocal guitar bass drums keyboard dj dancer manipulator].freeze

  # Scopes
  scope :birthday_on, lambda { |date|
    where('EXTRACT(MONTH FROM birthday) = ? AND EXTRACT(DAY FROM birthday) = ?',
          date.month, date.day)
  }

  STATUS_TRANSLATIONS = {
    'pre' => '準備中',
    'active' => '活動中',
    'free' => 'フリー',
    'hiatus' => '活動休止',
    'retirement' => '引退',
    'passed_away' => '死去',
    'unknown' => '不明'
  }.freeze

  DUMMY_BIRTH_YEAR = 1904 # Leap year for Feb 29 compatibility

  before_save :normalize_birthday_year

  validate :key_immutable, on: :update
  after_create :auto_link_unit_people
  after_commit :expire_sidebar_cache

  def name
    CGI.unescapeHTML(super.to_s).presence
  end

  def status_text
    STATUS_TRANSLATIONS[status] || status.humanize
  end

  def vkdb_url
    return nil if old_key.blank?

    "https://www.vkdb.jp/#{old_key}.html"
  end

  def birthday_display
    return nil unless birthday

    if birth_year.present?
      # Show full date with year
      Date.new(birth_year, birthday.month, birthday.day).strftime('%Y年%-m月%-d日')
    else
      # Show only month and day
      birthday.strftime('%-m月%-d日')
    end
  end

  # old_historyをパースして履歴アイテムの配列を返す
  # 戻り値: [
  #   [
  #     { unit_name: "ユニット名", part_and_name: "Part" or "Part+PersonName" or "PersonName", old_key: "EUC-JPエンコードされたユニット名", external_url: "外部URL" },
  #     ... (同時期の活動)
  #   ],
  #   ...
  # ]
  def parse_old_history
    parse_history_string(old_history)
  end

  # Person logs for form (virtual attribute)
  def name_logs
    require 'ostruct'
    (self[:name_log] || []).map { |entry| ::OpenStruct.new(entry) }
  end

  def name_logs_attributes=(attributes)
    # attributes is a hash like { "0" => { "name" => "...", "name_kana" => "..." }, ... }
    # specific structure depends on how fields_for sends data

    # Filter out empty entries
    new_logs = attributes.values.reject do |attrs|
      attrs['name'].blank?
    end

    # Convert to array of hashes for JSON storage
    self.name_log = new_logs.map do |attrs|
      {
        name: attrs['name'],
        name_kana: attrs['name_kana']
      }
    end
  end

  def aliases
    require 'ostruct'
    (self[:aliases] || []).map { |a| ::OpenStruct.new(a) }
  end

  def aliases_attributes=(attributes)
    self[:aliases] = attributes.values.reject { |a| a['name'].blank? }.map do |a|
      { name: CGI.unescapeHTML(a['name'].to_s), kana: a['kana'].to_s }
    end
  end

  def normalize_birthday_year
    return unless birthday

    # Always set birthday year to DUMMY_BIRTH_YEAR (1904)
    self.birthday = birthday.change(year: DUMMY_BIRTH_YEAR)
  end

  def key_immutable
    return unless key_changed? && key_was.present?

    errors.add(:key, 'cannot be changed once set')
  end

  def auto_link_unit_people
    return if key.blank?

    UnitPerson.where(person_key: key, person_id: nil).update_all(person_id: id)
  end

  def expire_sidebar_cache
    Rails.cache.delete('sidebar/recently_updated')
  end
end

# frozen_string_literal: true

# == Schema Information
#
# Table name: units
#
#  id            :bigint           not null, primary key
#  key           :string
#  name          :string
#  name_kana     :string
#  name_log      :jsonb
#  note          :text
#  old_key       :string
#  old_wiki_text :text
#  status        :integer          default("active"), not null
#  unit_type     :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  old_wiki_id   :integer
#
# Indexes
#
#  index_units_on_key        (key) UNIQUE
#  index_units_on_name       (name)
#  index_units_on_name_kana  (name_kana)
#  index_units_on_old_key    (old_key) UNIQUE
#
require 'cgi'
require 'ostruct'

class Unit < ApplicationRecord
  has_many :links, as: :linkable, dependent: :destroy
  accepts_nested_attributes_for :links, allow_destroy: true, reject_if: proc { |attrs| attrs['url'].blank? }
  has_many :unit_people
  has_many :people, through: :unit_people
  has_many :unit_logs, dependent: :destroy
  has_many :person_logs, dependent: :destroy
  has_many :tag_index_items, as: :indexable, dependent: :destroy
  has_many :tag_indices, through: :tag_index_items
  has_many :sections, as: :sectionable, dependent: :destroy
  has_many :unit_snapshots, dependent: :destroy
  enum :unit_type, { band: 0, unit: 1, session: 2, solo: 3, limited: 4, other: 99 }
  enum :status, { pre: 0, active: 1, freeze: 2, disbanded: 3, unknown: 99 }

  validates :status, presence: true

  STATUS_TRANSLATIONS = {
    'pre' => '準備中',
    'active' => '活動中',
    'freeze' => '活動休止',
    'disbanded' => '解散',
    'unknown' => '不明'
  }.freeze

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

  def name_logs
    (name_log || []).map { |h| OpenStruct.new(h) }
  end

  def activity_periods
    (activity_period || []).map { |h| OpenStruct.new(h) }
  end

  def name_logs_attributes=(attributes)
    self.name_log = attributes.values.map do |attrs|
      next if attrs['name'].blank?

      {
        name: attrs['name'],
        name_kana: attrs['name_kana'],
        date: attrs['date']
      }
    end.compact
  end

  def aliases
    (self[:aliases] || []).map { |a| OpenStruct.new(a) }
  end

  def aliases_attributes=(attributes)
    self[:aliases] = attributes.values.reject { |a| a['name'].blank? }.map do |a|
      { name: CGI.unescapeHTML(a['name'].to_s), kana: a['kana'].to_s }
    end
  end

  private

  after_create :link_related_person_logs_and_members

  def link_related_person_logs_and_members
    return if key.blank?

    logs = PersonLog.where(unit_key: key)
    return if logs.empty?

    logs.update_all(unit_id: id)

    logs.includes(:person).order(:log_date).each do |log|
      next unless log.person

      member = unit_people.find_or_initialize_by(person: log.person)

      # Determine part
      target_part = log.part
      member.part = target_part if UnitPerson.parts.keys.include?(target_part)

      # Set default status if new record
      member.status ||= :active

      member.save!
    end
  end
end

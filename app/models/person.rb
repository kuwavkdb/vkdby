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
#  old_history   :text
#  old_key       :string
#  old_wiki_text :text
#  parts         :json
#  status        :integer          default("active"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_people_on_key      (key) UNIQUE
#  index_people_on_name     (name)
#  index_people_on_old_key  (old_key) UNIQUE
#
class Person < ApplicationRecord
  has_many :links, as: :linkable, dependent: :destroy
  has_many :unit_people
  has_many :units, through: :unit_people
  has_many :person_logs
  has_many :tag_index_items, as: :indexable, dependent: :destroy
  has_many :tag_indices, through: :tag_index_items

  accepts_nested_attributes_for :links, allow_destroy: true, reject_if: :all_blank

  enum :status, { pre: 0, active: 1, free: 2, hiatus: 3, retirement: 90, passed_away: 98, unknown: 99 }

  # Valid parts for a person
  AVAILABLE_PARTS = %w[vocal guitar bass drums keyboard dj dancer manipulator].freeze

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
  def parse_old_history # rubocop:disable Metrics/PerceivedComplexity
    return [] if old_history.blank?

    require_relative '../../lib/tasks/wikipage_parser'

    timeline = []

    # Split by → and process each period
    old_history.split('→').each do |period_segment|
      period_segment = period_segment.strip
      next if period_segment.empty?

      concurrent_items = []

      # Split by 、 to handle concurrent activities
      period_segment.split('、').each do |item_segment|
        item_segment = item_segment.strip
        next if item_segment.empty?

        # Check if the entire segment is wrapped in parentheses
        wrapped_in_parens = item_segment.start_with?('(') && item_segment.end_with?(')')

        # Remove outer parentheses for pattern matching if wrapped
        content = wrapped_in_parens ? item_segment[1..-2] : item_segment

        # Pattern 1: [[UnitName]] or [[UnitName]](Part) - Internal unit link
        case content
        when /\[\[([^\]]+)\]\](?:\(([^)]+)\))?/
          unit_text = ::Regexp.last_match(1)
          part_and_name = ::Regexp.last_match(2)

          # [[XXXX|YYYY]] の場合、XXXXが表示名、YYYYがold_key(エンコード前)
          if unit_text.include?('|')
            display_name, raw_old_key = unit_text.split('|', 2)
          else
            display_name = unit_text
            raw_old_key = unit_text
          end

          # old_key生成用にEUC-JPエンコード
          encoded_unit_name = WikipageParser::Utils.encode_euc_jp_url(raw_old_key.strip)

          # If wrapped in parentheses, add them to display
          display_unit_name = wrapped_in_parens ? "(#{display_name.strip})" : display_name.strip

          concurrent_items << {
            unit_name: display_unit_name,
            part_and_name: part_and_name&.strip,
            old_key: encoded_unit_name
          }
        # Pattern 2: [LinkText|URL] or [LinkText|URL](Part) - External link
        when /\[([^\]|]+)\|([^\]]+)\](?:\(([^)]+)\))?/
          link_text = ::Regexp.last_match(1)
          url = ::Regexp.last_match(2)
          part_and_name = ::Regexp.last_match(3)

          # If wrapped in parentheses, add them to display
          display_link_text = wrapped_in_parens ? "(#{link_text.strip})" : link_text.strip

          concurrent_items << {
            unit_name: display_link_text,
            part_and_name: part_and_name&.strip,
            external_url: url.strip
          }
        # Pattern 3: Plain text - No link, display as-is (including parentheses)
        else
          concurrent_items << {
            unit_name: item_segment.strip
          }
        end
      end

      timeline << concurrent_items if concurrent_items.any?
    end

    timeline
  end

  # Person logs for form (virtual attribute)
  def name_logs
    require 'ostruct'
    return person_logs.map { |log| ::OpenStruct.new(log.attributes) } if person_logs.loaded?

    person_log_entries = self[:name_log] || []
    person_log_entries.map { |entry| ::OpenStruct.new(entry) }
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

  private

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
end

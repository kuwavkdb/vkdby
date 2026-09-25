# frozen_string_literal: true

# == Schema Information
#
# Table name: venues
#
#  id            :bigint           not null, primary key
#  address       :string
#  aliases       :jsonb            not null
#  area          :string
#  capacity      :integer
#  discarded_at  :datetime
#  key           :string           not null
#  name          :string           not null
#  name_kana     :string
#  name_log      :jsonb            not null
#  note          :text
#  old_key       :string
#  old_wiki_text :text
#  prefecture    :string
#  status        :integer          default("active"), not null
#  venue_type    :integer          default("live_house"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  old_wiki_id   :integer
#
# Indexes
#
#  index_venues_on_aliases_trgm   ((aliases)::text) USING gin
#  index_venues_on_discarded_at   (discarded_at)
#  index_venues_on_key            (key) UNIQUE
#  index_venues_on_name           (name) USING gin
#  index_venues_on_name_log_trgm  ((name_log)::text) USING gin
#  index_venues_on_old_key        (old_key) UNIQUE
#  index_venues_on_prefecture     (prefecture)
#  index_venues_on_venue_type     (venue_type)
#
require 'ostruct'

# ライブハウス・ホールなどの会場（issue #1685, #1687）。
# name_log/aliasesの形はUnitに揃えている。name_logは現在の名前も含めた名前の履歴で、
# 各要素のdateはその名前を使い始めた日（YYYY / YYYY-MM / YYYY-MM-DD）。
class Venue < ApplicationRecord
  include Discard::Model

  has_many :links, as: :linkable, dependent: :destroy
  accepts_nested_attributes_for :links, allow_destroy: true, reject_if: proc { |attrs| attrs['url'].blank? }
  has_many :wiki_page_imports, as: :import_target

  enum :venue_type, { live_house: 0, hall: 1, studio: 2, outdoor: 3, streaming: 4, other: 99 }
  enum :status, { active: 1, closed: 2, unknown: 99 }

  VENUE_TYPE_TRANSLATIONS = {
    'live_house' => 'ライブハウス',
    'hall' => 'ホール',
    'studio' => 'スタジオ',
    'outdoor' => '野外',
    'streaming' => '配信',
    'other' => 'その他'
  }.freeze

  STATUS_TRANSLATIONS = {
    'active' => '営業中',
    'closed' => '閉店',
    'unknown' => '不明'
  }.freeze

  PREFECTURES = %w[
    北海道 青森県 岩手県 宮城県 秋田県 山形県 福島県
    茨城県 栃木県 群馬県 埼玉県 千葉県 東京都 神奈川県
    新潟県 富山県 石川県 福井県 山梨県 長野県 岐阜県 静岡県 愛知県
    三重県 滋賀県 京都府 大阪府 兵庫県 奈良県 和歌山県
    鳥取県 島根県 岡山県 広島県 山口県
    徳島県 香川県 愛媛県 高知県
    福岡県 佐賀県 長崎県 熊本県 大分県 宮崎県 鹿児島県 沖縄県
    海外
  ].freeze

  # name_logのdateに使える書式（区切りは - / . のいずれか）
  NAME_LOG_DATE_PATTERN = %r{\A(\d{4})(?:[-/.](\d{1,2})(?:[-/.](\d{1,2}))?)?\z}

  # old_keyはDBにunique制約があるため、未入力の空文字列をnilに正規化する（CustomPageと同じ。issue #1305）
  before_validation { self.old_key = old_key.presence }
  before_validation { self.prefecture = prefecture.presence }

  validates :key, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :old_key, uniqueness: true, allow_blank: true
  validates :prefecture, inclusion: { in: PREFECTURES }, allow_nil: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :name_log_dates_must_be_valid

  def venue_type_text
    VENUE_TYPE_TRANSLATIONS[venue_type] || venue_type.to_s.humanize
  end

  def status_text
    STATUS_TRANSLATIONS[status] || status.to_s.humanize
  end

  def name_logs
    (name_log || []).map { |h| OpenStruct.new(h) }
  end

  # フォームから受け取った値はreload前でも文字列キーで参照できるよう、文字列キーのハッシュにする
  def name_logs_attributes=(attributes)
    self.name_log = attributes.values.filter_map do |attrs|
      next if attrs['name'].blank?

      {
        'name' => attrs['name'].to_s.strip,
        'name_kana' => attrs['name_kana'].to_s.strip.presence,
        'date' => attrs['date'].to_s.strip.presence
      }.compact
    end
  end

  def aliases
    (self[:aliases] || []).map { |a| OpenStruct.new(a) }
  end

  def aliases_attributes=(attributes)
    self[:aliases] = attributes.values.reject { |a| a['name'].blank? }.map do |a|
      {
        'name' => a['name'].to_s.strip,
        'kana' => a['kana'].to_s.strip.presence,
        'old_key' => a['old_key'].to_s.strip.presence,
        'hidden' => ActiveModel::Type::Boolean.new.cast(a['hidden']).presence
      }.compact
    end
  end

  # 指定日時点の名前を返す。name_logのうち使用開始日が指定日以前のもので最も新しいものを採用し、
  # 該当がなければ（日付の入った履歴がない・指定日が最初の履歴より前など）現在の名前を返す。
  # 後続のTrendでの会場表示名（issue #1689）で使う。
  def name_at(date)
    return name if date.blank?

    target = date.to_date
    entry = dated_name_logs.select { |start, _| start <= target }.max_by(&:first)
    entry ? entry.last['name'] : name
  end

  # name_logのdate文字列（YYYY / YYYY-MM / YYYY-MM-DD）を、その期間の初日として解釈する
  def self.parse_name_log_date(value)
    match = NAME_LOG_DATE_PATTERN.match(value.to_s.strip)
    return nil unless match

    Date.new(match[1].to_i, (match[2] || 1).to_i, (match[3] || 1).to_i)
  rescue Date::Error
    nil
  end

  private

  def dated_name_logs
    (name_log || []).filter_map do |entry|
      next if entry['name'].blank?

      start = self.class.parse_name_log_date(entry['date'])
      [start, entry] if start
    end
  end

  def name_log_dates_must_be_valid
    invalid = (name_log || []).map { |entry| entry['date'] }
                              .select { |value| value.present? && self.class.parse_name_log_date(value).nil? }
    return if invalid.empty?

    errors.add(:name_log, "の日付の形式が正しくありません（YYYY / YYYY-MM / YYYY-MM-DD）: #{invalid.join(', ')}")
  end
end

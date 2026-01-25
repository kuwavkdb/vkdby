# == Schema Information
#
# Table name: people
#
#  id                 :bigint           not null, primary key
#  birth_year_unknown :boolean
#  birthday           :date
#  blood              :string(255)
#  hometown           :string(255)
#  key                :string(255)
#  name               :string(255)
#  name_kana          :string(255)
#  old_key            :string(255)
#  parts              :json
#  status             :integer          default("active"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
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

  enum :status, { pre: 0, active: 1, free: 2, hiatus: 3, retirement: 90, passed_away: 98, unknown: 99 }

  # Valid parts for a person
  AVAILABLE_PARTS = %w[vocal guitar bass drums keyboard dj dancer manipulator]

  STATUS_TRANSLATIONS = {
    "pre" => "準備中",
    "active" => "活動中",
    "free" => "フリー",
    "hiatus" => "活動休止",
    "retirement" => "引退",
    "passed_away" => "死去",
    "unknown" => "不明"
  }

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
      Date.new(birth_year, birthday.month, birthday.day).strftime("%Y年%-m月%-d日")
    else
      # Show only month and day
      birthday.strftime("%-m月%-d日")
    end
  end

  private

  def normalize_birthday_year
    return unless birthday

    # Always set birthday year to DUMMY_BIRTH_YEAR (1904)
    self.birthday = birthday.change(year: DUMMY_BIRTH_YEAR)
  end

  def key_immutable
    if key_changed? && key_was.present?
      errors.add(:key, "cannot be changed once set")
    end
  end

  def auto_link_unit_people
    return if key.blank?

    UnitPerson.where(person_key: key, person_id: nil).update_all(person_id: id)
  end
end

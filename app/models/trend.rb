# frozen_string_literal: true

# == Schema Information
#
# Table name: trends
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  content           :text
#  date              :date             not null
#  day_unknown       :boolean          default(FALSE), not null
#  etc_phenomenon    :integer
#  month_unknown     :boolean          default(FALSE), not null
#  people            :jsonb
#  person_phenomenon :integer
#  publish_start_at  :datetime         not null
#  quote             :text
#  quote_title       :string
#  quote_url         :string
#  title             :string
#  unit_phenomenon   :integer
#  units             :jsonb
#  via_name          :string
#  via_url           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  old_trend_id      :integer
#  old_wiki_id       :integer
#
# Indexes
#
#  index_trends_on_date    (date)
#  index_trends_on_people  (people) USING gin
#  index_trends_on_units   (units) USING gin
#
class Trend < ApplicationRecord
  # Enums
  enum :unit_phenomenon, {
    announcement: 1,
    formation: 2,
    first_live: 3,
    finish: 4,
    pending: 5,
    rename: 6,
    suspend: 7,
    restart: 8,
    limited: 9,
    etc: 98,
    unknown: 99,
    other: 100
  }, prefix: true

  enum :person_phenomenon, {
    original_member: 0,
    join_member: 1,
    leave_member: 2,
    suspend_member: 3,
    rename_member: 4,
    convert: 5,
    stay: 6,
    dismissal: 7,
    rejoin: 8,
    retirement: 90,
    passed_away: 98,
    unknown: 99,
    other: 100
  }, prefix: true

  enum :etc_phenomenon, {
    unknown: 99,
    other: 100
  }, prefix: true

  # Validations
  validates :date, presence: true
  validates :active, inclusion: { in: [true, false] }
  validates :publish_start_at, presence: true
  validate :must_have_at_least_one_phenomenon

  private

  def must_have_at_least_one_phenomenon
    return if unit_phenomenon.present? || person_phenomenon.present? || etc_phenomenon.present?

    errors.add(:base, 'At least one phenomenon (unit, person, or etc) must be present')
  end
end

# == Schema Information
#
# Table name: units
#
#  id         :bigint           not null, primary key
#  key        :string(255)
#  name       :string(255)
#  name_kana  :string(255)
#  old_key    :string(255)
#  status     :integer          default("active"), not null
#  unit_type  :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_units_on_key      (key) UNIQUE
#  index_units_on_name     (name)
#  index_units_on_old_key  (old_key) UNIQUE
#
class Unit < ApplicationRecord
  has_many :links, as: :linkable, dependent: :destroy
  has_many :unit_people
  has_many :people, through: :unit_people
  has_many :unit_logs, dependent: :destroy
  has_many :person_logs, dependent: :destroy
  enum :unit_type, { band: 0, unit: 1, session: 2, solo: 3 }
  enum :status, { pre: 0, active: 1, freeze: 2, disbanded: 3, unknown: 99 }

  validates :status, presence: true

  STATUS_TRANSLATIONS = {
    "pre" => "準備中",
    "active" => "活動中",
    "freeze" => "活動休止",
    "disbanded" => "解散",
    "unknown" => "不明"
  }

  def status_text
    STATUS_TRANSLATIONS[status] || status.humanize
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
      if UnitPerson.parts.keys.include?(target_part)
        member.part = target_part
      end

      # Set default status if new record
      member.status ||= :active
      
      member.save!
    end
  end
end

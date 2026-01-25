# == Schema Information
#
# Table name: unit_people
#
#  id              :bigint           not null, primary key
#  inline_history  :text
#  old_person_key  :string
#  order_in_period :integer          default(1), not null
#  part            :integer          default("vocal"), not null
#  period          :integer          default(1), not null
#  person_key      :string
#  person_name     :string
#  sns             :json
#  status          :integer          default("active"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  person_id       :bigint
#  unit_id         :bigint           not null
#
# Indexes
#
#  index_unit_people_on_old_person_key                          (old_person_key)
#  index_unit_people_on_person_id                               (person_id)
#  index_unit_people_on_unit_id                                 (unit_id)
#  index_unit_people_on_unit_id_and_period_and_order_in_period  (unit_id,period,order_in_period)
#
# Foreign Keys
#
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (unit_id => units.id)
#
class UnitPerson < ApplicationRecord
  belongs_to :unit
  belongs_to :person, optional: true

  enum :status, { undefined: 0, active: 1, pending: 2, left: 3, concerned: 4, pre: 5 }
  enum :part, { vocal: 0, guitar: 1, bass: 2, drums: 3, keyboard: 4, dj: 5, unknown: 99 }

  validates :status, presence: true
  validates :part, presence: true
  validate :person_or_name_presence

  before_validation :find_person_by_key, if: -> { person_id.blank? && person_key.present? }

  def name
    person_name.presence || person&.name
  end

  def key
    person&.key || person_key
  end

  private

  def person_or_name_presence
    if person_id.blank? && person_name.blank?
      errors.add(:base, "Person or Person Name must be present")
    end
  end

  def find_person_by_key
    found_person = Person.find_by(key: person_key)
    if found_person
      self.person = found_person
    end
  end
end

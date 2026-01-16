# == Schema Information
#
# Table name: unit_people
#
#  id         :bigint           not null, primary key
#  part       :integer          default("vocal"), not null
#  status     :integer          default("active"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  person_id  :bigint           not null
#  unit_id    :bigint           not null
#
# Indexes
#
#  index_unit_people_on_person_id  (person_id)
#  index_unit_people_on_unit_id    (unit_id)
#
# Foreign Keys
#
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (unit_id => units.id)
#
class UnitPerson < ApplicationRecord
  belongs_to :unit
  belongs_to :person

  enum :status, { pre: 0, active: 1, pending: 2, left: 3, concerned: 4 }
  enum :part, { vocal: 0, guitar: 1, bass: 2, drums: 3, keyboard: 4, dj: 5 }

  validates :status, presence: true
  validates :part, presence: true
end

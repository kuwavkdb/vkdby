# frozen_string_literal: true

# == Schema Information
#
# Table name: snapshot_people
#
#  id               :bigint           not null, primary key
#  inline_history   :text
#  name_alias       :string
#  old_person_key   :string
#  part             :integer          default("vocal"), not null
#  part_alias       :string
#  person_key       :string
#  person_name      :string
#  sns              :json
#  sort_order       :integer          default(0), not null
#  status           :integer          default("active"), not null
#  support          :boolean          default(FALSE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  person_id        :bigint
#  unit_snapshot_id :bigint           not null
#
# Indexes
#
#  index_snapshot_people_on_old_person_key               (old_person_key)
#  index_snapshot_people_on_person_id                    (person_id)
#  index_snapshot_people_on_person_key                   (person_key)
#  index_snapshot_people_on_unit_snapshot_id             (unit_snapshot_id)
#  index_snapshot_people_on_unit_snapshot_id_and_sort_order  (unit_snapshot_id,sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (unit_snapshot_id => unit_snapshots.id)
#
class SnapshotPerson < ApplicationRecord
  include Discard::Model
  include WikiParser

  default_scope { kept }

  belongs_to :unit_snapshot
  belongs_to :person, optional: true

  enum :status, { undefined: 0, active: 1, pending: 2, left: 3, concerned: 4, pre: 5 }
  enum :part, { vocal: 0, guitar: 1, bass: 2, drums: 3, keyboard: 4, dj: 5, unknown: 99 }

  validates :status, presence: true
  validates :part, presence: true
  validate :person_or_name_presence

  before_validation :find_person_by_key, if: -> { person_id.blank? && person_key.present? }

  def name
    name_alias.presence || person_name.presence || person&.name
  end

  def key
    person&.key || person_key
  end

  def parse_inline_history
    parse_history_string(inline_history)
  end

  private

  def person_or_name_presence
    return unless person_id.blank? && person_name.blank?

    errors.add(:base, 'Person or Person Name must be present')
  end

  def find_person_by_key
    found_person = Person.find_by(key: person_key)
    return unless found_person

    self.person = found_person
  end
end

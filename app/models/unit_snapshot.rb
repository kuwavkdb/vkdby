# frozen_string_literal: true

# == Schema Information
#
# Table name: unit_snapshots
#
#  id            :bigint           not null, primary key
#  current       :boolean          default(FALSE), not null
#  label         :string
#  snapshot_date :date             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  unit_id       :bigint           not null
#
# Indexes
#
#  index_unit_snapshots_on_unit_id                    (unit_id)
#  index_unit_snapshots_on_unit_id_and_current        (unit_id,current)
#  index_unit_snapshots_on_unit_id_and_snapshot_date  (unit_id,snapshot_date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (unit_id => units.id)
#
class UnitSnapshot < ApplicationRecord
  belongs_to :unit
  has_many :snapshot_people, dependent: :destroy

  validates :snapshot_date, presence: true
  validates :snapshot_date, uniqueness: { scope: :unit_id }

  scope :chronological, -> { order(snapshot_date: :asc) }
  scope :reverse_chronological, -> { order(snapshot_date: :desc) }

  def display_label
    label.presence || snapshot_date.strftime('%Y/%m/%d')
  end
end

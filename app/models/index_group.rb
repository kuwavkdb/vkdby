# frozen_string_literal: true

# == Schema Information
#
# Table name: index_groups
#
#  id                  :bigint           not null, primary key
#  active              :boolean          default(TRUE), not null
#  name                :string           not null
#  people_filter_order :integer
#  sort_order          :integer          default(0), not null
#  units_filter_order  :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
class IndexGroup < ApplicationRecord
  has_many :tag_indices, dependent: :nullify

  scope :ordered, -> { order(sort_order: :asc) }
  scope :active, -> { where(active: true) }
  scope :for_units, -> { active.where.not(units_filter_order: nil).order(units_filter_order: :asc) }
  scope :for_people, -> { active.where.not(people_filter_order: nil).order(people_filter_order: :asc) }

  validates :name, presence: true
end

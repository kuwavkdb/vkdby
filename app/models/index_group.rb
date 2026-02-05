# frozen_string_literal: true

# == Schema Information
#
# Table name: index_groups
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  name       :string           not null
#  sort_order :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class IndexGroup < ApplicationRecord
  has_many :tag_indices, dependent: :nullify

  scope :ordered, -> { order(sort_order: :asc) }
  scope :active, -> { where(active: true) }

  validates :name, presence: true
end

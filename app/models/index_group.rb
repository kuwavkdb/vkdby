# frozen_string_literal: true

class IndexGroup < ApplicationRecord
  has_many :tag_indices, dependent: :nullify

  scope :ordered, -> { order(sort_order: :asc) }
  scope :active, -> { where(active: true) }

  validates :name, presence: true
end

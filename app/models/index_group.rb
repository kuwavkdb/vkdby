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

  def self.tag_filter_options_for_units
    tag_filter_options(for_units)
  end

  def self.tag_filter_options_for_people
    tag_filter_options(for_people)
  end

  def self.tag_filter_options(groups_scope)
    groups_scope.includes(:tag_indices).filter_map do |group|
      tags = group.tag_indices.select(&:active?).sort_by { |t| t.order_in_group || Float::INFINITY }
      { id: group.id, name: group.name, tags: tags.map { |t| { id: t.id, name: t.name } } } if tags.any?
    end
  end
end

# frozen_string_literal: true

# == Schema Information
#
# Table name: tag_indices
#
#  id             :bigint           not null, primary key
#  active         :boolean          default(TRUE), not null
#  name           :string           not null
#  order_in_group :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  index_group_id :integer
#
# Indexes
#
#  index_tag_indices_on_index_group_id                     (index_group_id)
#  index_tag_indices_on_index_group_id_and_order_in_group  (index_group_id,order_in_group)
#  index_tag_indices_on_name                               (name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (index_group_id => index_groups.id)
#
class TagIndex < ApplicationRecord
  has_many :items, class_name: 'TagIndexItem', dependent: :destroy
  has_many :people, through: :items, source: :indexable, source_type: 'Person'
  has_many :units, through: :items, source: :indexable, source_type: 'Unit'

  belongs_to :index_group, optional: true

  validates :name, presence: true, uniqueness: true

  scope :ordered, -> { order(order_in_group: :asc) }
  scope :active, -> { where(active: true) }
end

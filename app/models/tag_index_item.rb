# frozen_string_literal: true

# == Schema Information
#
# Table name: tag_index_items
#
#  id             :bigint           not null, primary key
#  indexable_type :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  indexable_id   :bigint           not null
#  tag_index_id   :bigint           not null
#
# Indexes
#
#  index_tag_index_items_on_indexable                       (indexable_type,indexable_id)
#  index_tag_index_items_on_tag_index_id                    (tag_index_id)
#  index_tag_index_items_on_tag_index_id_and_indexable_type  (tag_index_id,indexable_type)
#
# Foreign Keys
#
#  fk_rails_...  (tag_index_id => tag_indices.id)
#
class TagIndexItem < ApplicationRecord
  belongs_to :tag_index
  belongs_to :indexable, polymorphic: true
end

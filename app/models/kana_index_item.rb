# frozen_string_literal: true

# == Schema Information
#
# Table name: kana_index_items
#
#  id              :bigint           not null, primary key
#  indexable_type  :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  indexable_id    :bigint           not null
#  kana_index_id   :bigint           not null
#
# Indexes
#
#  index_kana_index_items_on_indexable                        (indexable_type,indexable_id)
#  index_kana_index_items_on_kana_index_id                    (kana_index_id)
#  index_kana_index_items_on_kana_index_id_and_indexable_type  (kana_index_id,indexable_type)
#
# Foreign Keys
#
#  fk_rails_...  (kana_index_id => kana_indices.id)
#
class KanaIndexItem < ApplicationRecord
  belongs_to :kana_index
  belongs_to :indexable, polymorphic: true
end

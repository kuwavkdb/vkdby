# frozen_string_literal: true

# == Schema Information
#
# Table name: kana_indices
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_kana_indices_on_name  (name) UNIQUE
#
class KanaIndex < ApplicationRecord
  has_many :items, class_name: 'KanaIndexItem', dependent: :destroy
  has_many :people, through: :items, source: :indexable, source_type: 'Person'
  has_many :units, through: :items, source: :indexable, source_type: 'Unit'

  validates :name, presence: true, uniqueness: true
end

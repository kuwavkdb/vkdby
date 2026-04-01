# frozen_string_literal: true

# == Schema Information
#
# Table name: sections
#
#  id               :bigint           not null, primary key
#  name             :string
#  wiki_text        :text
#  sort_order       :integer
#  sectionable_type :string           not null
#  sectionable_id   :bigint           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_sections_on_sectionable  (sectionable_type,sectionable_id)
#
class Section < ApplicationRecord
  include Discard::Model

  belongs_to :sectionable, polymorphic: true
  has_many_attached :images

  validates :name, presence: true
end

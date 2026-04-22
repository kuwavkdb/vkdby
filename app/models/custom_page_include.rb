# frozen_string_literal: true

# == Schema Information
#
# Table name: custom_page_includes
#
#  id                    :bigint           not null, primary key
#  section_name          :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  source_custom_page_id :bigint           not null
#  target_custom_page_id :bigint           not null
#
# Indexes
#
#  index_custom_page_includes_on_source_custom_page_id  (source_custom_page_id)
#  index_custom_page_includes_on_target_custom_page_id  (target_custom_page_id)
#
# Foreign Keys
#
#  fk_rails_...  (source_custom_page_id => custom_pages.id)
#  fk_rails_...  (target_custom_page_id => custom_pages.id)
#

class CustomPageInclude < ApplicationRecord
  belongs_to :source_custom_page, class_name: 'CustomPage'
  belongs_to :target_custom_page, class_name: 'CustomPage'

  validates :section_name, presence: true
end

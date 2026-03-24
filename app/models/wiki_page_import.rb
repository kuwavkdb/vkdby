# frozen_string_literal: true

# == Schema Information
#
# Table name: wiki_page_imports
#
#  id                 :bigint           not null, primary key
#  page_type          :string
#  last_imported_at   :datetime
#  status             :string           not null, default("pending")
#  import_target_type :string
#  import_target_id   :bigint
#  note               :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  wikipage_id        :bigint           not null
#
# Indexes
#
#  index_wiki_page_imports_on_wikipage_id  (wikipage_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (wikipage_id => wikipages.id)
#

class WikiPageImport < ApplicationRecord
  STATUSES = %w[pending imported skipped error].freeze
  PAGE_TYPES = %w[unit person other].freeze

  belongs_to :wikipage
  belongs_to :import_target, polymorphic: true, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :page_type, inclusion: { in: PAGE_TYPES }, allow_nil: true

  scope :pending,  -> { where(status: 'pending') }
  scope :imported, -> { where(status: 'imported') }
  scope :skipped,  -> { where(status: 'skipped') }
  scope :error,    -> { where(status: 'error') }
end

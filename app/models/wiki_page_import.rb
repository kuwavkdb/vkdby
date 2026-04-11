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
#  manually_set       :boolean          not null, default(false)
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
  STATUSES = %w[pending imported skipped deferred error ignored].freeze
  PAGE_TYPES = %w[unit person live_house custom_page omnibus moved office_label other].freeze
  PAGE_TYPE_LABELS = {
    'unit' => 'ユニット',
    'person' => '人物',
    'live_house' => 'ライブハウス',
    'custom_page' => 'カスタムページ',
    'omnibus' => 'オムニバス',
    'moved' => '移動',
    'office_label' => '事務所/レーベル',
    'other' => 'その他'
  }.freeze

  belongs_to :wikipage
  belongs_to :import_target, polymorphic: true, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :page_type, inclusion: { in: PAGE_TYPES }, allow_nil: true

  scope :pending,       -> { where(status: 'pending') }
  scope :imported,      -> { where(status: 'imported') }
  scope :skipped,       -> { where(status: 'skipped') }
  scope :deferred,      -> { where(status: 'deferred') }
  scope :error,         -> { where(status: 'error') }
  scope :ignored,       -> { where(status: 'ignored') }
  scope :manually_set,  -> { where(manually_set: true) }
end

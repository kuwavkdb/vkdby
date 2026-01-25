# == Schema Information
#
# Table name: unit_logs
#
#  id               :bigint           not null, primary key
#  log_date         :date
#  phenomenon       :integer
#  phenomenon_alias :string
#  quote_text       :text
#  source_url       :string
#  text             :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  unit_id          :bigint           not null
#
# Indexes
#
#  index_unit_logs_on_unit_id  (unit_id)
#
# Foreign Keys
#
#  fk_rails_...  (unit_id => units.id)
#
class UnitLog < ApplicationRecord
  belongs_to :unit

  enum :phenomenon, { announcement: 1, first_live: 2, finish: 3, pending: 5, rename: 6, pause: 7, etc: 98, unknown: 99 }, prefix: true

  validates :phenomenon, presence: true

  PHENOMENON_TRANSLATIONS = {
    "announcement" => "結成",
    "first_live" => "始動",
    "finish" => "解散",
    "pending" => "保留",
    "rename" => "改名",
    "pause" => "活動休止",
    "etc" => "その他",
    "unknown" => "不明"
  }

  def phenomenon_text
    phenomenon_alias.presence || PHENOMENON_TRANSLATIONS[phenomenon] || phenomenon&.humanize
  end
end

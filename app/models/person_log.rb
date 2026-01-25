# == Schema Information
#
# Table name: person_logs
#
#  id               :bigint           not null, primary key
#  log_date         :string
#  log_type         :integer
#  name             :string
#  part             :integer
#  phenomenon       :integer          not null
#  phenomenon_alias :string
#  quote_text       :text
#  sort_order       :integer
#  source_url       :string
#  text             :text
#  unit_key         :string
#  unit_name        :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  person_id        :bigint           not null
#  unit_id          :bigint
#
# Indexes
#
#  index_person_logs_on_person_id                 (person_id)
#  index_person_logs_on_person_id_and_sort_order  (person_id,sort_order)
#  index_person_logs_on_unit_id                   (unit_id)
#
# Foreign Keys
#
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (unit_id => units.id)
#
class PersonLog < ApplicationRecord
  belongs_to :person
  belongs_to :unit, optional: true

  enum :phenomenon, { original_member: 0, join: 1, leave: 2, pending: 3, rename: 4, convert: 5, stay: 6, retirement: 90, passed_away: 98, unknown: 99 }, prefix: true
  enum :part, { vocal: 0, guitar: 1, bass: 2, drums: 3, keyboard: 4, dj: 5, etc: 99 }

  validates :phenomenon, presence: true
  validates :log_date, format: { with: /\A\d{4}(\/\d{2}(\/\d{2})?)?\z/ }, allow_blank: true

  PHENOMENON_TRANSLATIONS = {
    "original_member" => "初期メンバー",
    "join" => "加入",
    "leave" => "脱退",
    "pending" => "保留",
    "rename" => "改名",
    "convert" => "コンバート",
    "stay" => "残留",
    "retirement" => "引退",
    "passed_away" => "死去",
    "unknown" => "不明"
  }

  def phenomenon_text
    phenomenon_alias.presence || PHENOMENON_TRANSLATIONS[phenomenon] || phenomenon&.humanize
  end

  def unit_name
    super.presence || unit&.name
  end
end

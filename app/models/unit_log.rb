# == Schema Information
#
# Table name: unit_logs
#
#  id         :bigint           not null, primary key
#  log_date   :date
#  phenomenon :integer
#  text       :text(65535)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  unit_id    :bigint           not null
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
end

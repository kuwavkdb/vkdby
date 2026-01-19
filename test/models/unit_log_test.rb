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
require "test_helper"

class UnitLogTest < ActiveSupport::TestCase
  test "should not save unit log without phenomenon" do
    unit_log = UnitLog.new(unit: units(:one), log_date: Date.today)
    assert_not unit_log.save, "Saved the unit log without a phenomenon"
  end
end

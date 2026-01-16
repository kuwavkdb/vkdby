# == Schema Information
#
# Table name: person_logs
#
#  id         :bigint           not null, primary key
#  log_date   :string(255)
#  log_type   :integer
#  name       :string(255)
#  part       :integer
#  sort_order :integer
#  status     :integer          not null
#  text       :text(65535)
#  unit_name  :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  person_id  :bigint           not null
#  unit_id    :bigint
#
# Indexes
#
#  index_person_logs_on_person_id  (person_id)
#  index_person_logs_on_unit_id    (unit_id)
#
# Foreign Keys
#
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (unit_id => units.id)
#
require "test_helper"

class PersonLogTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

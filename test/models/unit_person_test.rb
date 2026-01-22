# == Schema Information
#
# Table name: unit_people
#
#  id              :bigint           not null, primary key
#  inline_history  :text(65535)
#  old_person_key  :string(255)
#  order_in_period :integer          default(1), not null
#  part            :integer          default("vocal"), not null
#  period          :integer          default(1), not null
#  person_key      :string(255)
#  person_name     :string(255)
#  sns             :json
#  status          :integer          default("active"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  person_id       :bigint
#  unit_id         :bigint           not null
#
# Indexes
#
#  index_unit_people_on_person_id                               (person_id)
#  index_unit_people_on_unit_id                                 (unit_id)
#  index_unit_people_on_unit_id_and_period_and_order_in_period  (unit_id,period,order_in_period)
#
# Foreign Keys
#
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (unit_id => units.id)
#
require "test_helper"

class UnitPersonTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

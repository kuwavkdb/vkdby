# == Schema Information
#
# Table name: units
#
#  id         :bigint           not null, primary key
#  key        :string(255)
#  name       :string(255)
#  name_kana  :string(255)
#  old_key    :string(255)
#  status     :integer          default("active"), not null
#  unit_type  :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_units_on_key      (key) UNIQUE
#  index_units_on_name     (name)
#  index_units_on_old_key  (old_key) UNIQUE
#
require "test_helper"

class UnitTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

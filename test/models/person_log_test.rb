# frozen_string_literal: true

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
require 'test_helper'

class PersonLogTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

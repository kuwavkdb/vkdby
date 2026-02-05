# frozen_string_literal: true

# == Schema Information
#
# Table name: trends
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  content           :text
#  date              :date             not null
#  day_unknown       :boolean          default(FALSE), not null
#  etc_phenomenon    :integer
#  month_unknown     :boolean          default(FALSE), not null
#  people            :jsonb
#  person_phenomenon :integer
#  publish_start_at  :datetime         not null
#  quote             :text
#  quote_title       :string
#  quote_url         :string
#  title             :string
#  unit_phenomenon   :integer
#  units             :jsonb
#  via_name          :string
#  via_url           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  old_trend_id      :integer
#  old_wiki_id       :integer
#
# Indexes
#
#  index_trends_on_date    (date)
#  index_trends_on_people  (people) USING gin
#  index_trends_on_units   (units) USING gin
#
require 'test_helper'

class TrendTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

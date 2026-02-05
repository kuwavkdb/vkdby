# frozen_string_literal: true

# == Schema Information
#
# Table name: old_trends
#
#  id                :bigint           not null, primary key
#  content           :text
#  hide_member       :integer
#  publish           :boolean
#  publish_plan_date :datetime
#  quote             :text
#  quote_url         :string
#  rss               :boolean
#  target_date       :string
#  target_name       :string
#  trend_class       :integer
#  via               :string
#  via_url           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  wikipage_id       :integer
#
class OldTrend < ApplicationRecord
end

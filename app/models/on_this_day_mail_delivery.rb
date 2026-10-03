# frozen_string_literal: true

# == Schema Information
#
# Table name: on_this_day_mail_deliveries
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  date       :date             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_on_this_day_mail_deliveries_on_date  (date) UNIQUE
#
# 「今日はなんの日？」投稿文メール（issue #1742）の送信記録。同じ日に二度送らないために使う
class OnThisDayMailDelivery < ApplicationRecord
  validates :date, presence: true, uniqueness: true
  validates :body, presence: true
end

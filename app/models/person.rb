# == Schema Information
#
# Table name: people
#
#  id         :bigint           not null, primary key
#  birthday   :date
#  blood      :string(255)
#  hometown   :string(255)
#  key        :string(255)
#  name       :string(255)
#  name_kana  :string(255)
#  old_key    :string(255)
#  status     :integer          default("active"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_people_on_key      (key) UNIQUE
#  index_people_on_name     (name)
#  index_people_on_old_key  (old_key) UNIQUE
#
class Person < ApplicationRecord
  has_many :links, as: :linkable, dependent: :destroy
  has_many :unit_people
  has_many :units, through: :unit_people
  has_many :person_logs

  enum :status, { pre: 0, active: 1, retirement: 90, passed_away: 98, unknown: 99 }
end

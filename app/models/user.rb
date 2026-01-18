# == Schema Information
#
# Table name: users
#
#  id              :bigint           not null, primary key
#  email           :string(255)      not null
#  name            :string(255)
#  password_digest :string(255)
#  role            :integer          default("operator"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#
class User < ApplicationRecord
  has_secure_password
  enum :role, { operator: 0, super_operator: 1, admin: 2 }, default: :operator

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  def super_operator_or_above?
    super_operator? || admin?
  end
end

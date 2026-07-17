# frozen_string_literal: true

# == Schema Information
#
# Table name: operation_logs
#
#  id             :bigint           not null, primary key
#  operation_type :string           not null
#  created_at     :datetime         not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_operation_logs_on_created_at      (created_at)
#  index_operation_logs_on_operation_type  (operation_type)
#  index_operation_logs_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class OperationLog < ApplicationRecord
  belongs_to :user

  OPERATION_TYPES = %w[login].freeze

  validates :operation_type, inclusion: { in: OPERATION_TYPES }
end

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
require 'test_helper'

class OperationLogTest < ActiveSupport::TestCase
  test 'valid with operation_type login' do
    log = OperationLog.new(user: users(:one), operation_type: 'login')
    assert log.valid?
  end

  test 'invalid with an unknown operation_type' do
    log = OperationLog.new(user: users(:one), operation_type: 'unknown')
    assert_not log.valid?
  end

  test 'invalid without a user' do
    log = OperationLog.new(operation_type: 'login')
    assert_not log.valid?
  end
end

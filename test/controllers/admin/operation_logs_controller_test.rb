# frozen_string_literal: true

require 'test_helper'

module Admin
  class OperationLogsControllerTest < ActionDispatch::IntegrationTest
    test 'should get index as admin' do
      post login_path, params: { email: users(:admin).email, password: 'password' }
      get admin_operation_logs_path
      assert_response :success
    end

    test 'should deny index for super_operator' do
      post login_path, params: { email: users(:one).email, password: 'password' }
      get admin_operation_logs_path
      assert_redirected_to root_path
    end

    test 'should redirect to login when not logged in' do
      get admin_operation_logs_path
      assert_redirected_to login_path
    end
  end
end

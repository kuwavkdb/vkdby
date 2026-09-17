# frozen_string_literal: true

require 'test_helper'

module Admin
  class TrendSubmissionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @submission = TrendSubmission.create!(target_type: :unit, target_name: 'Pending Unit',
                                            date: Date.new(2026, 1, 1), via_url: 'https://example.com',
                                            phenomenon: Trend.unit_phenomenons['announcement'])
    end

    test 'index requires admin role' do
      post login_path, params: { email: users(:one).email, password: 'password' }

      get admin_trend_submissions_path

      assert_redirected_to root_path
    end

    test 'index lists pending submissions by default' do
      login_as_admin

      get admin_trend_submissions_path

      assert_response :success
      assert_includes response.body, @submission.target_name
    end

    test 'index filters by status' do
      login_as_admin
      rejected = TrendSubmission.create!(target_type: :unit, target_name: 'Rejected Unit',
                                         date: Date.new(2026, 1, 1), via_url: 'https://example.com/rejected',
                                         phenomenon: Trend.unit_phenomenons['announcement'],
                                         submission_status: :rejected)

      get admin_trend_submissions_path(status: 'rejected')

      assert_response :success
      assert_includes response.body, rejected.target_name
      assert_not_includes response.body, @submission.target_name
    end

    test 'reject requires admin role' do
      post login_path, params: { email: users(:one).email, password: 'password' }

      patch reject_admin_trend_submission_path(@submission)

      assert_redirected_to root_path
      assert_predicate @submission.reload, :pending?
    end

    test 'reject marks the submission as rejected' do
      login_as_admin

      patch reject_admin_trend_submission_path(@submission)

      assert_redirected_to admin_trend_submissions_path
      assert_predicate @submission.reload, :rejected?
    end

    private

    def login_as_admin
      post login_path, params: { email: users(:admin).email, password: 'password' }
    end
  end
end

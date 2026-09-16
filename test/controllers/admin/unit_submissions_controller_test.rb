# frozen_string_literal: true

require 'test_helper'

module Admin
  class UnitSubmissionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @submission = UnitSubmission.create!(name: 'Pending Unit', unit_type: :band, status: :active,
                                           links_attributes: { '0' => { url: 'https://example.com' } })
    end

    test 'index requires admin role' do
      post login_path, params: { email: users(:one).email, password: 'password' }

      get admin_unit_submissions_path

      assert_redirected_to root_path
    end

    test 'index lists pending submissions by default' do
      login_as_admin

      get admin_unit_submissions_path

      assert_response :success
      assert_includes response.body, @submission.name
    end

    test 'index filters by status' do
      login_as_admin
      rejected = UnitSubmission.create!(name: 'Rejected Unit', unit_type: :band, status: :active,
                                        submission_status: :rejected,
                                        links_attributes: { '0' => { url: 'https://example.com/rejected' } })

      get admin_unit_submissions_path(status: 'rejected')

      assert_response :success
      assert_includes response.body, rejected.name
      assert_not_includes response.body, @submission.name
    end

    test 'reject requires admin role' do
      post login_path, params: { email: users(:one).email, password: 'password' }

      patch reject_admin_unit_submission_path(@submission)

      assert_redirected_to root_path
      assert_predicate @submission.reload, :pending?
    end

    test 'reject marks the submission as rejected' do
      login_as_admin

      patch reject_admin_unit_submission_path(@submission)

      assert_redirected_to admin_unit_submissions_path
      assert_predicate @submission.reload, :rejected?
    end

    private

    def login_as_admin
      post login_path, params: { email: users(:admin).email, password: 'password' }
    end
  end
end

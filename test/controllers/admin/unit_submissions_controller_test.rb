# frozen_string_literal: true

require 'test_helper'

module Admin
  class UnitSubmissionsControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

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

    test 'index shows attached images and the usage consent' do
      login_as_admin
      attach_image(@submission)

      get admin_unit_submissions_path

      assert_response :success
      assert_select 'img[alt=?]', 'Pending Unit の投稿画像1'
      assert_includes response.body, 'サイト上での利用: 了承済み'
    end

    test 'reject purges attached images' do
      login_as_admin
      attach_image(@submission)

      assert_enqueued_with(job: ActiveStorage::PurgeJob) do
        patch reject_admin_unit_submission_path(@submission)
      end

      assert_predicate @submission.reload, :rejected?
    end

    test 'index lets admins copy converted submission images as markdown' do
      login_as_admin
      attach_image(@submission)
      @submission.update!(submission_status: :converted, converted_unit: units(:one))

      get admin_unit_submissions_path(status: 'converted')

      assert_response :success
      assert_select 'button[data-markdown]', count: 1 do |buttons|
        assert_match %r{\A!\[MyString\]\(/rails/active_storage/blobs/(?:redirect|proxy)/[^)]+/image\.png\)\z},
                     buttons.first['data-markdown']
      end
      assert_not_includes response.body, 'サイト上での利用: 了承済み'
    end

    test 'index does not offer markdown copy without image usage consent' do
      login_as_admin
      attach_image(@submission)
      @submission.update_columns(image_usage_consented: false)
      @submission.update!(submission_status: :converted, converted_unit: units(:one))

      get admin_unit_submissions_path(status: 'converted')

      assert_response :success
      assert_select 'button[data-markdown]', count: 0
    end

    test 'index does not offer markdown copy for pending submissions' do
      login_as_admin
      attach_image(@submission)

      get admin_unit_submissions_path

      assert_response :success
      assert_select 'button[data-markdown]', count: 0
    end

    private

    def attach_image(submission)
      submission.update!(is_related_person: true, image_usage_consented: true)
      submission.images.attach(io: file_fixture('submission_image.png').open, filename: 'image.png',
                               content_type: 'image/png')
    end

    def login_as_admin
      post login_path, params: { email: users(:admin).email, password: 'password' }
    end
  end
end

# frozen_string_literal: true

require 'test_helper'

module Admin
  class UnitSubmissionsControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
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

    test 'index lets admins add converted submission images to the unit' do
      login_as_admin
      attach_image(@submission)
      @submission.update!(submission_status: :converted, converted_unit: units(:one))

      get admin_unit_submissions_path(status: 'converted')

      assert_response :success
      assert_select 'form[action=?] button', add_image_to_unit_admin_unit_submission_path(@submission), count: 1
      assert_not_includes response.body, 'サイト上での利用: 了承済み'
    end

    test 'index does not offer adding images without image usage consent' do
      login_as_admin
      attach_image(@submission)
      @submission.update_columns(image_usage_consented: false)
      @submission.update!(submission_status: :converted, converted_unit: units(:one))

      get admin_unit_submissions_path(status: 'converted')

      assert_response :success
      assert_select 'form[action=?]', add_image_to_unit_admin_unit_submission_path(@submission), count: 0
    end

    test 'index does not offer adding images for pending submissions' do
      login_as_admin
      attach_image(@submission)

      get admin_unit_submissions_path

      assert_response :success
      assert_select 'form[action=?]', add_image_to_unit_admin_unit_submission_path(@submission), count: 0
    end

    test 'add_image_to_unit requires admin role' do
      post login_path, params: { email: users(:one).email, password: 'password' }
      attachment = attach_image(@submission)
      @submission.update!(submission_status: :converted, converted_unit: units(:one))

      post add_image_to_unit_admin_unit_submission_path(@submission), params: { attachment_id: attachment.id }

      assert_redirected_to root_path
      assert_equal 1, @submission.images.reload.count
    end

    test 'add_image_to_unit moves the image to the image section of the converted unit' do
      login_as_admin
      attachment = attach_image(@submission)
      unit = units(:one)
      @submission.update!(submission_status: :converted, converted_unit: unit)

      assert_difference(-> { unit.sections.count } => 1, -> { UpdateLog.count } => 1) do
        post add_image_to_unit_admin_unit_submission_path(@submission), params: { attachment_id: attachment.id }
      end

      assert_redirected_to admin_unit_submissions_path(status: 'converted')
      section = unit.sections.find_by!(name: UnitSubmissionImageTransfer::SECTION_NAME)
      assert_equal [attachment.blob_id], section.images.map(&:blob_id)
      assert_match %r{/rails/active_storage/blobs/(?:redirect|proxy)/#{Regexp.escape(attachment.blob.signed_id)}/},
                   section.markdown
      assert_not @submission.reload.images.attached?
    end

    test 'add_image_to_unit refuses images without image usage consent' do
      login_as_admin
      attachment = attach_image(@submission)
      @submission.update_columns(image_usage_consented: false)
      @submission.update!(submission_status: :converted, converted_unit: units(:one))

      assert_no_difference(-> { Section.count }) do
        post add_image_to_unit_admin_unit_submission_path(@submission), params: { attachment_id: attachment.id }
      end

      assert_equal 'この画像はUnitに追加できません', flash[:alert]
      assert_equal 1, @submission.images.reload.count
    end

    test 'add_image_to_unit refuses images of another submission' do
      login_as_admin
      other = UnitSubmission.create!(name: 'Other Unit', unit_type: :band, status: :active,
                                     links_attributes: { '0' => { url: 'https://example.com/other' } })
      other_attachment = attach_image(other)
      attach_image(@submission)
      @submission.update!(submission_status: :converted, converted_unit: units(:one))

      assert_no_difference(-> { Section.count }) do
        post add_image_to_unit_admin_unit_submission_path(@submission), params: { attachment_id: other_attachment.id }
      end

      assert_equal '画像が見つかりませんでした', flash[:alert]
      assert_equal 1, other.images.reload.count
    end

    private

    def attach_image(submission)
      submission.update!(is_related_person: true, image_usage_consented: true)
      submission.images.attach(io: file_fixture('submission_image.png').open, filename: 'image.png',
                               content_type: 'image/png')
      submission.images_attachments.reload.last
    end

    def login_as_admin
      post login_path, params: { email: users(:admin).email, password: 'password' }
    end
  end
end

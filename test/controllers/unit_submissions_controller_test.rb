# frozen_string_literal: true

require 'test_helper'

class UnitSubmissionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def valid_params
    {
      unit_submission: {
        name: 'New Unit From Fan',
        name_kana: 'ニューユニット',
        unit_type: 'band',
        status: 'active',
        note: 'まだ掲載されていないようです',
        email: 'fan@example.com',
        is_related_person: '0',
        links_attributes: { '0' => { text: '公式サイト', url: 'https://example.com/band' } }
      }
    }
  end

  test 'new renders successfully without login' do
    get new_unit_submission_path

    assert_response :success
  end

  test 'create saves a submission and notifies admin users' do
    assert_difference('UnitSubmission.count') do
      assert_enqueued_emails 1 do
        post unit_submissions_path, params: valid_params
      end
    end

    submission = UnitSubmission.last
    assert_equal 'New Unit From Fan', submission.name
    assert_equal 'https://example.com/band', submission.links.first.url
    assert_predicate submission, :pending?
    assert_equal '127.0.0.1', submission.submitter_ip
    assert_redirected_to new_unit_submission_path
  end

  test 'create rejects a submission without a name' do
    assert_no_difference('UnitSubmission.count') do
      post unit_submissions_path, params: valid_params.deep_merge(unit_submission: { name: '' })
    end

    assert_response :unprocessable_entity
  end

  test 'create rejects a submission without any links' do
    assert_no_difference('UnitSubmission.count') do
      post unit_submissions_path, params: valid_params.deep_merge(unit_submission: { links_attributes: { '0' => { url: '' } } })
    end

    assert_response :unprocessable_entity
  end

  def image_params(is_related_person:, consented: '1')
    valid_params.deep_merge(
      unit_submission: {
        is_related_person: is_related_person,
        image_usage_consented: consented,
        image_files: [fixture_file_upload('submission_image.png', 'image/png')]
      }
    )
  end

  def with_stubbed_sanitizer(&)
    result = lambda do |file|
      SubmissionImageSanitizer::Result.new(io: StringIO.new(File.binread(file.path)), filename: 'sanitized.png',
                                           content_type: 'image/png')
    end
    stub_class_method(SubmissionImageSanitizer, :call, result, &)
  end

  test 'new renders the image fields hidden and disabled by default' do
    get new_unit_submission_path

    assert_select 'fieldset.hidden[disabled][data-unit-submission-form-target=images]' do
      assert_select 'input[type=file][name=?]', 'unit_submission[image_files][]'
      assert_select 'input[type=checkbox][name=?]', 'unit_submission[image_usage_consented]'
    end
  end

  test 'create attaches images submitted by a related person with consent' do
    with_stubbed_sanitizer do
      assert_difference('UnitSubmission.count') do
        post unit_submissions_path, params: image_params(is_related_person: '1')
      end
    end

    submission = UnitSubmission.last
    assert_equal 1, submission.images.count
    assert_predicate submission, :image_usage_consented?
    assert_redirected_to new_unit_submission_path
  end

  test 'create silently drops images when the submitter is not a related person' do
    with_stubbed_sanitizer do
      assert_difference('UnitSubmission.count') do
        post unit_submissions_path, params: image_params(is_related_person: '0')
      end
    end

    submission = UnitSubmission.last
    assert_not submission.images.attached?
    assert_not submission.image_usage_consented?
    assert_redirected_to new_unit_submission_path
  end

  test 'create rejects images without consent and keeps the image fields visible' do
    with_stubbed_sanitizer do
      assert_no_difference('UnitSubmission.count') do
        post unit_submissions_path, params: image_params(is_related_person: '1', consented: '0')
      end
    end

    assert_response :unprocessable_entity
    assert_select 'fieldset[data-unit-submission-form-target=images]:not(.hidden):not([disabled])'
  end
end

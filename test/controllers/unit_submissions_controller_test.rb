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
end

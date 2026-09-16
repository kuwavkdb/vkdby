# frozen_string_literal: true

require 'test_helper'

class TrendSubmissionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def valid_params(overrides = {})
    {
      trend_submission: {
        target_type: 'unit',
        target_name: 'New Unit From Fan',
        date: '2026-01-01',
        title: '結成しました',
        content: '詳細はリンク先を参照',
        via_url: 'https://example.com/announcement',
        phenomenon: Trend.unit_phenomenons['announcement'],
        email: 'fan@example.com',
        is_related_person: '0'
      }.merge(overrides)
    }
  end

  test 'new renders successfully without login' do
    get new_trend_submission_path

    assert_response :success
  end

  test 'new prefills hidden target fields when linked from a profile page' do
    get new_trend_submission_path(target_type: 'unit', target_id: 123, target_name: 'Fixed Unit')

    assert_response :success
    assert_includes response.body, 'Fixed Unit'
  end

  test 'create saves a submission and notifies admin users' do
    assert_difference('TrendSubmission.count') do
      assert_enqueued_emails 1 do
        post trend_submissions_path, params: valid_params
      end
    end

    submission = TrendSubmission.last
    assert_equal 'New Unit From Fan', submission.target_name
    assert_predicate submission, :unit?
    assert_predicate submission, :pending?
    assert_equal '127.0.0.1', submission.submitter_ip
    assert_redirected_to new_trend_submission_path
  end

  test 'create preserves target context in the redirect when target_id was fixed' do
    post trend_submissions_path, params: valid_params(target_id: '123')

    assert_redirected_to new_trend_submission_path(target_type: 'unit', target_id: '123', target_name: 'New Unit From Fan')
  end

  test 'create rejects a submission without a via_url' do
    assert_no_difference('TrendSubmission.count') do
      post trend_submissions_path, params: valid_params(via_url: '')
    end

    assert_response :unprocessable_entity
  end

  test 'create rejects a submission without a phenomenon' do
    assert_no_difference('TrendSubmission.count') do
      post trend_submissions_path, params: valid_params(phenomenon: '')
    end

    assert_response :unprocessable_entity
  end

  test 'create rejects a submission without a target_name' do
    assert_no_difference('TrendSubmission.count') do
      post trend_submissions_path, params: valid_params(target_name: '')
    end

    assert_response :unprocessable_entity
  end
end

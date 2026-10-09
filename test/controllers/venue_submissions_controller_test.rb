# frozen_string_literal: true

require 'test_helper'

# 会場の投稿フォーム（issue #1814）
class VenueSubmissionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', prefecture: '東京都', area: '新宿')
  end

  def new_venue_params(overrides = {})
    { venue_submission: { name: '下北沢の新しい会場', name_kana: 'しもきたざわのあたらしいかいじょう', prefecture: '東京都',
                          area: '下北沢', address: '東京都世田谷区北沢1-1', venue_type: 'live_house', capacity: '200',
                          source_url: 'https://example.com/venue', note: '2026年オープン', email: 'fan@example.com' }.merge(overrides) }
  end

  test 'new renders the new venue form without login' do
    get new_venue_submission_path

    assert_response :success
    assert_select 'h1', text: '会場の情報を投稿する'
    assert_select "input[name='venue_submission[name]'][required]"
    assert_select "select[name='venue_submission[prefecture]'][required]"
  end

  test 'create saves a new venue submission and notifies admins' do
    assert_difference -> { VenueSubmission.count }, 1 do
      assert_enqueued_emails User.admin.count do
        post venue_submissions_path, params: new_venue_params
      end
    end

    assert_redirected_to new_venue_submission_path
    submission = VenueSubmission.last
    assert submission.new_venue?
    assert submission.pending?
    assert_equal ['下北沢の新しい会場', '東京都', 'live_house', 200, '127.0.0.1'],
                 [submission.name, submission.prefecture, submission.venue_type, submission.capacity, submission.submitter_ip]
  end

  test 'create re-renders the form with errors when required fields are missing' do
    assert_no_difference -> { VenueSubmission.count } do
      post venue_submissions_path, params: new_venue_params(name: '', prefecture: '')
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']", text: /入力エラー/
    assert_select '#venue_submission_name_error'
  end

  test 'create asks for confirmation when a similar venue exists, then accepts it' do
    assert_no_difference -> { VenueSubmission.count } do
      post venue_submissions_path, params: new_venue_params(name: '新宿LOFT')
    end

    assert_response :unprocessable_entity
    assert_select "a[href='#{venue_path(@venue.key)}']", text: '新宿LOFT'
    assert_select "a[href='#{new_venue_submission_path(venue_id: @venue.id)}']", text: 'この会場の訂正を送る'
    assert_select "input[name='confirmed'][value='1']"

    assert_difference -> { VenueSubmission.count }, 1 do
      post venue_submissions_path, params: new_venue_params(name: '新宿LOFT').merge(confirmed: '1')
    end
  end

  test 'new renders the correction form for a venue' do
    get new_venue_submission_path(venue_id: @venue.id)

    assert_response :success
    assert_select 'h1', text: '会場の情報の訂正を送る'
    assert_select "a[href='#{venue_path(@venue.key)}']", text: '新宿LOFT'
    assert_select "textarea[name='venue_submission[correction]'][required]"
    assert_select "input[name='venue_submission[name]']", count: 0
  end

  test 'create saves a correction and returns to the venue page' do
    assert_difference -> { VenueSubmission.count }, 1 do
      post venue_submissions_path, params: { venue_id: @venue.id,
                                             venue_submission: { correction: '2025年に閉店しました', name: '書き換え' } }
    end

    assert_redirected_to venue_path(@venue.key)
    submission = VenueSubmission.last
    assert submission.correction?
    assert_equal @venue, submission.venue
    assert_equal '2025年に閉店しました', submission.correction
    assert_nil submission.name
  end

  test 'a correction requires the correction text' do
    post venue_submissions_path, params: { venue_id: @venue.id, venue_submission: { correction: '' } }

    assert_response :unprocessable_entity
    assert_select '#venue_submission_correction_error'
  end

  test 'corrections of discarded venues are not accepted' do
    @venue.discard

    get new_venue_submission_path(venue_id: @venue.id)
    assert_response :not_found

    post venue_submissions_path, params: { venue_id: @venue.id, venue_submission: { correction: '閉店' } }
    assert_response :not_found
  end

  test 'venue pages and lists link to the submission form' do
    get venue_path(@venue.key)
    assert_select "a[href='#{new_venue_submission_path(venue_id: @venue.id)}']", text: 'この会場の情報の訂正を送る'

    get venues_path
    assert_select "a[href='#{new_venue_submission_path}']", text: '会場の情報を投稿する'

    get venue_prefecture_path('東京都')
    assert_select "a[href='#{new_venue_submission_path}']", text: '会場の情報を投稿する'
  end
end

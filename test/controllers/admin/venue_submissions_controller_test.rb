# frozen_string_literal: true

require 'test_helper'

module Admin
  # 会場の投稿の管理（issue #1814）
  class VenueSubmissionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', prefecture: '東京都')
      @new_venue = VenueSubmission.create!(submission_kind: :new_venue, name: '投稿された会場', prefecture: '大阪府',
                                           area: '心斎橋', venue_type: 'hall', capacity: 500,
                                           source_url: 'https://example.com/new', email: 'fan@example.com',
                                           submitter_ip: '192.0.2.1')
      @correction = VenueSubmission.create!(submission_kind: :correction, venue: @venue, correction: '閉店しました')
    end

    def login_as(user)
      post login_path, params: { email: user.email, password: 'password' }
    end

    test 'requires admin role' do
      login_as(users(:one))

      get admin_venue_submissions_path
      assert_redirected_to root_path

      patch reject_admin_venue_submission_path(@new_venue)
      assert_redirected_to root_path
      assert @new_venue.reload.pending?
    end

    test 'index lists pending submissions and filters by kind and status' do
      login_as(users(:admin))

      get admin_venue_submissions_path
      assert_response :success
      assert_includes response.body, '投稿された会場'
      assert_includes response.body, '閉店しました'
      assert_includes response.body, '192.0.2.1'
      assert_select "a[href='#{new_admin_venue_path(venue_submission_id: @new_venue.id)}']", text: '登録する'

      get admin_venue_submissions_path(kind: 'correction')
      assert_not_includes response.body, '投稿された会場'
      assert_includes response.body, '閉店しました'

      get admin_venue_submissions_path(status: 'rejected')
      assert_not_includes response.body, '投稿された会場'
    end

    test 'reject marks the submission as rejected' do
      login_as(users(:admin))

      patch reject_admin_venue_submission_path(@new_venue)

      assert @new_venue.reload.rejected?
    end

    test 'resolve marks a correction as converted' do
      login_as(users(:admin))

      patch resolve_admin_venue_submission_path(@correction)

      @correction.reload
      assert @correction.converted?
      assert_equal @venue, @correction.converted_venue
    end

    test 'new venue form is prefilled from the submission and creating converts it' do
      login_as(users(:admin))

      get new_admin_venue_path(venue_submission_id: @new_venue.id)
      assert_response :success
      assert_select "input[name='venue[name]'][value='投稿された会場']"
      assert_select "select[name='venue[prefecture]'] option[selected][value='大阪府']"
      assert_select "input[name='venue_submission_id'][value='#{@new_venue.id}']"
      assert_includes response.body, 'https://example.com/new'

      post admin_venues_path, params: { venue_submission_id: @new_venue.id,
                                        venue: { key: 'submitted-venue', name: '投稿された会場', prefecture: '大阪府',
                                                 venue_type: 'hall' } }

      venue = Venue.find_by!(key: 'submitted-venue')
      assert_redirected_to edit_admin_venue_path(venue)
      @new_venue.reload
      assert @new_venue.converted?
      assert_equal venue, @new_venue.converted_venue
    end

    test 'creating a venue is rolled back when converting the submission fails' do
      login_as(users(:admin))

      stub_instance_method(VenueSubmission, :update!, ->(*) { raise ActiveRecord::RecordNotSaved, 'failed' }) do
        post admin_venues_path, params: { venue_submission_id: @new_venue.id,
                                          venue: { key: 'submitted-venue', name: '投稿された会場' } }
      rescue ActiveRecord::RecordNotSaved
        nil
      end

      assert_nil Venue.find_by(key: 'submitted-venue')
      assert @new_venue.reload.pending?
    end

    test 'operators do not take over submissions in the venue form' do
      operator = User.create!(email: 'operator@example.com', name: 'Operator', password: 'password', role: :operator)
      login_as(operator)

      get new_admin_venue_path(venue_submission_id: @new_venue.id)
      assert_response :success
      assert_select "input[name='venue_submission_id']", count: 0

      post admin_venues_path, params: { venue_submission_id: @new_venue.id,
                                        venue: { key: 'operator-venue', name: '投稿された会場' } }
      assert @new_venue.reload.pending?
    end

    test 'venue edit page shows pending corrections to admins only' do
      login_as(users(:admin))
      get edit_admin_venue_path(@venue)
      assert_includes response.body, '閉店しました'
      assert_select "form[action='#{resolve_admin_venue_submission_path(@correction)}']"

      login_as(users(:one))
      get edit_admin_venue_path(@venue)
      assert_not_includes response.body, '閉店しました'
    end

    test 'venue edit page keeps showing pending corrections when the update fails' do
      login_as(users(:admin))
      patch admin_venue_path(@venue), params: { venue: { name: '' } }

      assert_response :unprocessable_entity
      assert_includes response.body, '閉店しました'
      assert_select "form[action='#{resolve_admin_venue_submission_path(@correction)}']"
    end
  end
end

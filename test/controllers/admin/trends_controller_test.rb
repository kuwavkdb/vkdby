# frozen_string_literal: true

require 'test_helper'

module Admin
  class TrendsControllerTest < ActionDispatch::IntegrationTest
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
      @trend = trends(:one)
    end

    test 'should get new' do
      get new_admin_trend_path
      assert_response :success
    end

    test 'should get edit' do
      get edit_admin_trend_path(@trend)
      assert_response :success
    end

    test 'should create trend with slash-separated date' do
      assert_difference('Trend.count') do
        post admin_trends_path, params: {
          trend: {
            date: '2024/03/15',
            publish_start_at: '2024-03-15 12:00:00',
            active: true,
            unit_phenomenon: 'announcement'
          }
        }
      end

      assert_equal Date.new(2024, 3, 15), Trend.last.date
    end
  end
end

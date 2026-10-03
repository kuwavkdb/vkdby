# frozen_string_literal: true

require 'test_helper'

module Internal
  class OnThisDayPostsControllerTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper

    TOKEN = 'test-on-this-day-token'

    setup do
      @original_token = ENV.fetch('ON_THIS_DAY_MAIL_TOKEN', nil)
      ENV['ON_THIS_DAY_MAIL_TOKEN'] = TOKEN
      unit = Unit.create!(name: '黒夢', key: 'on-this-day-post-unit', status: :active)
      Trend.create!(title: '解散', date: Date.new(1999, 5, 30), publish_start_at: Time.utc(2000, 1, 1),
                    unit_phenomenon: :finish, units: [{ 'unit_id' => unit.id, 'name' => unit.name }])
    end

    teardown do
      ENV['ON_THIS_DAY_MAIL_TOKEN'] = @original_token
    end

    test 'JSTの当日の投稿文を返す。メールは送らない（issue #1742）' do
      # UTC 5/29 15:00 = JST 5/30 0:00
      travel_to Time.utc(2026, 5, 29, 15, 0) do
        assert_no_emails do
          get internal_on_this_day_post_path, headers: auth_header
        end
      end

      assert_response :success
      body = response.parsed_body
      assert_equal 'ok', body['status']
      assert_equal '05-30', body['date']
      assert_includes body['text'], '・1999年 黒夢 解散'
      assert_equal XPostLength.count(body['text']), body['weighted_length']
      assert_equal XPostLength::MAX, body['max_length']
      assert body['intent_url'].start_with?('https://x.com/intent/post?text=')
      assert body['page_url'].end_with?('/date/-/5/30')
    end

    test '日付を指定できる' do
      get internal_on_this_day_post_path, params: { date: '05-30' }, headers: auth_header

      assert_equal 'ok', response.parsed_body['status']
      assert_equal '05-30', response.parsed_body['date']
    end

    test '動向も誕生日もない日は no_content を返す' do
      get internal_on_this_day_post_path, params: { date: '05-31' }, headers: auth_header

      assert_response :success
      body = response.parsed_body
      assert_equal 'no_content', body['status']
      assert_nil body['text']
      assert body['page_url'].end_with?('/date/-/5/31')
    end

    test 'トークンが違えば401' do
      get internal_on_this_day_post_path, headers: { 'Authorization' => 'Bearer wrong' }

      assert_response :unauthorized
    end

    test 'トークンが未設定ならエンドポイントごと無効（404）' do
      ENV['ON_THIS_DAY_MAIL_TOKEN'] = nil

      get internal_on_this_day_post_path, headers: auth_header

      assert_response :not_found
    end

    test '日付の形式が不正なら422' do
      get internal_on_this_day_post_path, params: { date: '13-40' }, headers: auth_header

      assert_response :unprocessable_entity
    end

    private

    def auth_header
      { 'Authorization' => "Bearer #{TOKEN}" }
    end
  end
end

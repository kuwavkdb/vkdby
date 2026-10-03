# frozen_string_literal: true

require 'test_helper'

module Internal
  class OnThisDayMailsControllerTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper

    TOKEN = 'test-on-this-day-token'

    setup do
      @original_token = ENV.fetch('ON_THIS_DAY_MAIL_TOKEN', nil)
      ENV['ON_THIS_DAY_MAIL_TOKEN'] = TOKEN
      unit = Unit.create!(name: '黒夢', key: 'on-this-day-mail-unit', status: :active)
      Trend.create!(title: '解散', date: Date.new(1999, 5, 30), publish_start_at: Time.utc(2000, 1, 1),
                    unit_phenomenon: :finish, units: [{ 'unit_id' => unit.id, 'name' => unit.name }])
    end

    teardown do
      ENV['ON_THIS_DAY_MAIL_TOKEN'] = @original_token
    end

    test 'JSTの当日の投稿文をadminにメールする（issue #1742）' do
      # UTC 5/29 15:00 = JST 5/30 0:00
      travel_to Time.utc(2026, 5, 29, 15, 0) do
        assert_emails User.admin.count do
          post internal_on_this_day_mail_path, headers: auth_header
        end
      end

      assert_response :success
      assert_equal({ 'status' => 'sent', 'date' => '2026-05-30' }, response.parsed_body)
      assert_includes ActionMailer::Base.deliveries.last.text_part.decoded, '・1999年 黒夢 解散'
    end

    test '日付を指定して送れる。再実行すれば再度送る' do
      assert_emails User.admin.count * 2 do
        2.times { post internal_on_this_day_mail_path, params: { date: '2026-05-30' }, headers: auth_header }
      end
      assert_equal({ 'status' => 'sent', 'date' => '2026-05-30' }, response.parsed_body)
    end

    test '動向も誕生日もない日は、送る内容がない旨をメールする' do
      assert_emails User.admin.count do
        post internal_on_this_day_mail_path, params: { date: '2026-05-31' }, headers: auth_header
      end
      assert_equal 'no_content', response.parsed_body['status']
      assert_equal '[VKDBY] 5月31日の「今日はなんの日？」投稿文はありません', ActionMailer::Base.deliveries.last.subject
    end

    test 'トークンが違えば401' do
      assert_no_emails do
        post internal_on_this_day_mail_path, headers: { 'Authorization' => 'Bearer wrong' }
      end
      assert_response :unauthorized
    end

    test 'トークンが未設定ならエンドポイントごと無効（404）' do
      ENV['ON_THIS_DAY_MAIL_TOKEN'] = nil

      post internal_on_this_day_mail_path, headers: auth_header

      assert_response :not_found
    end

    test '日付の形式が不正なら422' do
      post internal_on_this_day_mail_path, params: { date: '2026-13-40' }, headers: auth_header

      assert_response :unprocessable_entity
    end

    private

    def auth_header
      { 'Authorization' => "Bearer #{TOKEN}" }
    end
  end
end

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
      assert_select "input[type=checkbox][name='trend[person_name_in_title]']"
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

    test 'should update person_name_in_title' do
      @trend.update!(unit_phenomenon: :other)

      patch admin_trend_path(@trend), params: {
        trend: {
          date: @trend.date.strftime('%Y/%m/%d'),
          publish_start_at: @trend.publish_start_at,
          active: @trend.active,
          unit_phenomenon: 'other',
          person_name_in_title: '1'
        }
      }

      assert_redirected_to edit_admin_trend_path(@trend)
      assert @trend.reload.person_name_in_title?
    end

    # issue #1553: 公開の投稿フォーム(TrendSubmission)から「承認」した際、内容が新規作成フォームに
    # 引き継がれ、保存すると投稿が「変換済み」になることを確認する
    test 'new prefills the form from a pending trend submission with a known target' do
      unit = units(:one)
      submission = TrendSubmission.create!(target_type: :unit, target_id: unit.id, target_name: unit.name,
                                           date: Date.new(2026, 1, 1), title: '結成しました',
                                           content: '詳細はリンク先を参照', via_url: 'https://example.com/submitted',
                                           phenomenon: Trend.unit_phenomenons['announcement'])

      get new_admin_trend_path(trend_submission_id: submission.id)

      assert_response :success
      assert_includes response.body, '結成しました'
      assert_includes response.body, 'https://example.com/submitted'
    end

    test 'new does not preset units when the trend submission has no known target_id' do
      submission = TrendSubmission.create!(target_type: :unit, target_name: 'Unlinked Unit',
                                           date: Date.new(2026, 1, 1), via_url: 'https://example.com/submitted',
                                           phenomenon: Trend.unit_phenomenons['announcement'])

      get new_admin_trend_path(trend_submission_id: submission.id)

      assert_response :success
      assert_select "div[data-autocomplete-field-name-value='units'] span", count: 0
    end

    test 'create converts the pending trend submission and links it to the created trend' do
      submission = TrendSubmission.create!(target_type: :unit, target_name: 'Submitted Unit',
                                           date: Date.new(2026, 1, 1), via_url: 'https://example.com/submitted',
                                           phenomenon: Trend.unit_phenomenons['announcement'])

      assert_difference('Trend.count') do
        post admin_trends_path, params: {
          trend: {
            date: '2026/01/01',
            publish_start_at: Time.current,
            active: true,
            unit_phenomenon: 'announcement'
          },
          trend_submission_id: submission.id
        }
      end

      submission.reload
      assert_predicate submission, :converted?
      assert_equal Trend.last, submission.converted_trend
    end
  end
end

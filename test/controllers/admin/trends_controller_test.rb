# frozen_string_literal: true

require 'test_helper'

module Admin
  class TrendsControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
      @trend = trends(:one)
    end

    test 'should get new' do
      get new_admin_trend_path
      assert_response :success
    end

    # issue #1582: 記事やXのポストから組み立てたURLで新規作成フォームを事前入力できることを確認する
    test 'new prefills the form from trend params in the URL' do
      get new_admin_trend_path(
        trend: {
          date: '2026-07-17', day_unknown: '1', title: 'Vo. [[Amon|天聞]] 引退', content: '引退を発表',
          quote: '<blockquote class="twitter-tweet">投稿</blockquote>',
          quote_url: 'https://twitter.com/amonn_uc/status/2034929759059419627',
          via_name: '@amonn_uc', via_url: 'https://example.com/via', person_phenomenon: 'retirement'
        }
      )

      assert_response :success
      assert_select "input[name='trend[date]'][value='2026/07/17']"
      assert_select "input[type=checkbox][name='trend[day_unknown]'][checked]"
      assert_select "input[name='trend[title]'][value=?]", 'Vo. [[Amon|天聞]] 引退'
      assert_select "input[name='trend[quote_url]'][value=?]", 'https://twitter.com/amonn_uc/status/2034929759059419627'
      assert_select "input[name='trend[via_name]'][value='@amonn_uc']"
      assert_select "select[name='trend[person_phenomenon]'] option[selected][value='retirement']"
      assert_select "textarea[name='trend[quote]']", text: /twitter-tweet/
    end

    test 'new ignores an undefined phenomenon key instead of raising' do
      get new_admin_trend_path(trend: { unit_phenomenon: 'no_such_phenomenon', title: 'テスト' })

      assert_response :success
      assert_select "input[name='trend[title]'][value='テスト']"
      assert_select "select[name='trend[unit_phenomenon]'] option[selected]", count: 0
    end

    test 'new does not accept attributes outside the prefill whitelist' do
      get new_admin_trend_path(trend: { title: 'テスト', publish_start_at: '2000-01-01T00:00', active: '0' })

      assert_response :success
      assert_select "input[type=checkbox][name='trend[active]'][checked]"
      assert_select "input[name='trend[publish_start_at]'][value^='2000']", count: 0
    end

    test 'new shows unit_name and person_name in the autocomplete inputs without selecting them' do
      get new_admin_trend_path(unit_name: 'ヤミテラ', person_name: 'J \'ω\'2')

      assert_response :success
      assert_select "div[data-autocomplete-field-name-value='units'] input[data-autocomplete-target='input'][value='ヤミテラ']"
      assert_select "div[data-autocomplete-field-name-value='people'] input[data-autocomplete-target='input'][value=?]", "J 'ω'2"
      assert_select "div[data-autocomplete-field-name-value='units'] span", count: 0
    end

    test 'new still presets the unit from unit_id as linked from the profile page' do
      unit = units(:one)

      get new_admin_trend_path(unit_id: unit.id)

      assert_response :success
      assert_select "div[data-autocomplete-field-name-value='units'] span", text: /#{Regexp.escape(unit.name)}/
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

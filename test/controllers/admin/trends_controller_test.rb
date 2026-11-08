# frozen_string_literal: true

require 'test_helper'

module Admin
  class TrendsControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
    include ActiveJob::TestHelper

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

    # issue #1692: trend-url スキルから会場名を渡すと、会場の検索欄に入るだけで紐付けや表示名の上書きはしない
    test 'new shows venue_name in the venue search input without linking it' do
      get new_admin_trend_path(venue_name: '渋谷CLUB QUATTRO')

      assert_response :success
      assert_select "input#trend_venue_search[value='渋谷CLUB QUATTRO']"
      assert_select "input[type=hidden][name='trend[venue_id]']:not([value])"
      assert_select "input[name='trend[venue_name]']:not([value])"
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

      assert_redirected_to edit_admin_trend_path(Trend.last)
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

    test 'new puts the venue name of the trend submission in the venue search input' do
      submission = TrendSubmission.create!(target_type: :unit, target_name: 'Submitted Unit',
                                           date: Date.new(2026, 1, 1), via_url: 'https://example.com/submitted',
                                           venue_name: '高田馬場CLUB PHASE',
                                           phenomenon: Trend.unit_phenomenons['announcement'])

      get new_admin_trend_path(trend_submission_id: submission.id)

      assert_response :success
      assert_select "input#trend_venue_search[value='高田馬場CLUB PHASE']"
      assert_select "input[type=hidden][name='trend[venue_id]']:not([value])"
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

      assert_redirected_to edit_admin_trend_path(Trend.last)
      submission.reload
      assert_predicate submission, :converted?
      assert_equal Trend.last, submission.converted_trend
    end

    # issue #1689: 会場の紐付け
    test 'create saves venue_id and venue_name' do
      venue = Venue.create!(key: 'club-quattro', name: 'CLUB QUATTRO')

      post admin_trends_path, params: {
        trend: { date: '2026/09/01', publish_start_at: Time.current, active: '1', unit_phenomenon: 'live',
                 title: 'ワンマン', venue_id: venue.id, venue_name: '渋谷CLUB QUATTRO' }
      }

      trend = Trend.last
      assert_equal venue, trend.venue
      assert_equal '渋谷CLUB QUATTRO', trend.venue_name
    end

    test 'create saves news_release (issue #2014)' do
      post admin_trends_path, params: {
        trend: { date: '2026/09/01', publish_start_at: Time.current, active: '1', unit_phenomenon: 'live',
                 title: 'ニュースリリースの動向', news_release: '1',
                 news_release_source: 'Example Records' }
      }

      assert Trend.last.news_release?
      assert_equal 'Example Records', Trend.last.news_release_source
    end

    test 'update attaches an image with alt text (issue #2014)' do
      patch admin_trend_path(@trend), params: {
        trend: { image: fixture_file_upload('submission_image.png', 'image/png'), image_alt: 'ジャケット写真' }
      }

      assert_redirected_to edit_admin_trend_path(@trend)
      @trend.reload
      assert @trend.image.attached?
      assert_equal 'ジャケット写真', @trend.image_alt
    end

    test 'update rejects a non-image file (issue #2014)' do
      patch admin_trend_path(@trend), params: {
        trend: { image: Rack::Test::UploadedFile.new(StringIO.new('not an image'), 'text/plain', original_filename: 'note.txt') }
      }

      assert_response :unprocessable_entity
      assert_not @trend.reload.image.attached?
    end

    test 'update attaches and removes the bottom image (issue #2014)' do
      patch admin_trend_path(@trend), params: {
        trend: { bottom_image: fixture_file_upload('submission_image.png', 'image/png'), bottom_image_alt: '告知画像' }
      }
      assert @trend.reload.bottom_image.attached?
      assert_equal '告知画像', @trend.bottom_image_alt

      perform_enqueued_jobs { patch admin_trend_path(@trend), params: { trend: { remove_bottom_image: '1' } } }

      assert_not @trend.reload.bottom_image.attached?
    end

    test 'edit renders the fields for both images (issue #2014)' do
      get edit_admin_trend_path(@trend)

      assert_response :success
      assert_select "input[type=file][name='trend[image]']"
      assert_select "input[type=file][name='trend[bottom_image]']"
      assert_select "input[name='trend[bottom_image_alt]']"
    end

    test 'new renders publish_start_at down to the minute (issue #2024)' do
      travel_to Time.zone.local(2026, 11, 6, 20, 55, 28) do
        get new_admin_trend_path
      end

      assert_response :success
      assert_select "input[type='datetime-local'][name='trend[publish_start_at]'][value='2026-11-06T20:55']"
    end

    test 'edit renders publish_start_at down to the minute (issue #2024)' do
      @trend.update!(publish_start_at: Time.zone.local(2026, 11, 7, 19, 59, 28))

      get edit_admin_trend_path(@trend)

      assert_response :success
      assert_select "input[type='datetime-local'][name='trend[publish_start_at]'][value='2026-11-07T19:59']"
    end

    test 'update can clear the venue' do
      venue = Venue.create!(key: 'club-quattro', name: 'CLUB QUATTRO')
      @trend.update!(venue: venue)

      patch admin_trend_path(@trend), params: { trend: { venue_id: '', venue_name: '' } }

      assert_redirected_to edit_admin_trend_path(@trend)
      @trend.reload
      assert_nil @trend.venue
      assert_nil @trend.venue_name
    end

    test 'edit shows the selected venue and its display name' do
      venue = Venue.create!(key: 'club-quattro', name: 'CLUB QUATTRO')
      @trend.update!(venue: venue)

      get edit_admin_trend_path(@trend)

      assert_response :success
      assert_select "input[type=hidden][name='trend[venue_id]'][value='#{venue.id}']"
      assert_select "[data-venue-picker-target='selectedName']", text: 'CLUB QUATTRO'
    end

    # issue #1923: 動向の削除
    test 'index shows the delete button as a form that sends DELETE' do
      get admin_trends_path

      assert_response :success
      assert_select "form[action='#{admin_trend_path(@trend)}'] input[name='_method'][value='delete']"
    end

    test 'index shows the publish_start_at of a scheduled trend in the status column (issue #2014)' do
      @trend.update!(active: true, publish_start_at: Time.zone.local(2099, 1, 2, 3, 4, 5))

      get admin_trends_path

      assert_response :success
      assert_includes response.body, '2099/01/02 03:04:05 公開'
    end

    test 'destroy deletes the trend and redirects to the index' do
      assert_difference('Trend.count', -1) do
        delete admin_trend_path(@trend)
      end

      assert_redirected_to admin_trends_path
    end

    test 'destroy deletes a trend converted from a submission and clears the reference' do
      submission = TrendSubmission.create!(target_type: :unit, target_name: 'Submitted Unit',
                                           date: Date.new(2026, 1, 1), via_url: 'https://example.com/submitted',
                                           phenomenon: Trend.unit_phenomenons['announcement'],
                                           submission_status: :converted, converted_trend: @trend)

      assert_difference('Trend.count', -1) do
        delete admin_trend_path(@trend)
      end

      assert_nil submission.reload.converted_trend_id
    end

    test 'edit shows the delete button only for an inactive trend' do
      @trend.update!(active: false)
      get edit_admin_trend_path(@trend)
      assert_select "form[action='#{admin_trend_path(@trend)}'] input[name='_method'][value='delete']"

      @trend.update!(active: true)
      get edit_admin_trend_path(@trend)
      assert_select "form[action='#{admin_trend_path(@trend)}'] input[name='_method'][value='delete']", count: 0
    end

    test 'operator sees no delete button on the index or the edit page' do
      User.create!(email: 'operator@example.com', name: 'Operator', password: 'password', role: :operator)
      post login_path, params: { email: 'operator@example.com', password: 'password' }
      @trend.update!(active: false)

      get admin_trends_path
      assert_select "form[action='#{admin_trend_path(@trend)}']", count: 0

      get edit_admin_trend_path(@trend)
      assert_select "form[action='#{admin_trend_path(@trend)}'] input[name='_method'][value='delete']", count: 0
    end
  end
end

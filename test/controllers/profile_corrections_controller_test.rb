# frozen_string_literal: true

require 'test_helper'

# ユニット・個人の情報の訂正の投稿フォーム（issue #1902）
class ProfileCorrectionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @unit = Unit.create!(key: 'correction-unit', name: '訂正ユニット', status: 'active')
    @person = Person.create!(key: 'correction-person', name: '訂正する人', status: :active)
  end

  def correction_params(key, overrides = {})
    { key: key,
      profile_correction: { correction: '結成日は2010年4月1日です', source_url: 'https://example.com/official',
                            note: '公式サイトに記載があります', email: 'fan@example.com' }.merge(overrides) }
  end

  test 'new renders the form for a unit without login' do
    get new_profile_correction_path(key: @unit.key)

    assert_response :success
    assert_select 'h1', text: '訂正ユニット の情報の訂正を送る'
    assert_select "input[type=hidden][name='key'][value='correction-unit']"
    assert_select "textarea[name='profile_correction[correction]'][required]"
  end

  test 'new returns 404 for unknown or provisional targets' do
    get new_profile_correction_path(key: 'no-such-key')
    assert_response :not_found

    @unit.update!(provisional: true)
    get new_profile_correction_path(key: @unit.key)
    assert_response :not_found
  end

  test 'create saves a correction for a unit and notifies admins' do
    assert_difference -> { ProfileCorrection.count }, 1 do
      assert_enqueued_emails User.admin.count do
        post profile_corrections_path, params: correction_params(@unit.key)
      end
    end

    assert_redirected_to profile_path(@unit.key)
    correction = ProfileCorrection.last
    assert_equal @unit, correction.target
    assert correction.pending?
    assert_equal ['結成日は2010年4月1日です', 'https://example.com/official', '127.0.0.1'],
                 [correction.correction, correction.source_url, correction.submitter_ip]
  end

  test 'create saves a correction for a person' do
    assert_difference -> { ProfileCorrection.count }, 1 do
      post profile_corrections_path, params: correction_params(@person.key, correction: '誕生日が違います')
    end

    assert_redirected_to profile_path(@person.key)
    assert_equal @person, ProfileCorrection.last.target
  end

  test 'create re-renders the form with errors when the correction is blank' do
    assert_no_difference -> { ProfileCorrection.count } do
      post profile_corrections_path, params: correction_params(@unit.key, correction: '')
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']", text: /入力エラー/
    assert_select '#profile_correction_correction_error'
  end

  test 'create does not fail when profile_correction is not a hash' do
    assert_no_difference -> { ProfileCorrection.count } do
      post profile_corrections_path, params: { key: @unit.key, profile_correction: 'x' }
    end

    assert_response :unprocessable_entity
  end

  test 'profile pages link to the correction form' do
    @unit.update!(unit_type: :band)
    get profile_path(@unit.key)
    assert_response :success
    assert_select "a[href='#{new_profile_correction_path(key: @unit.key)}']", text: /このバンドの情報の訂正を送る/

    # バンド以外の種類のユニットは「ユニット」と呼ぶ
    @unit.update!(unit_type: :solo)
    get profile_path(@unit.key)
    assert_select "a[href='#{new_profile_correction_path(key: @unit.key)}']", text: /このユニットの情報の訂正を送る/

    get profile_path(@person.key)
    assert_response :success
    assert_select "a[href='#{new_profile_correction_path(key: @person.key)}']", text: /この人の情報の訂正を送る/
  end
end

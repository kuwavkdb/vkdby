# frozen_string_literal: true

require 'test_helper'

module Admin
  # ユニット・個人の情報の訂正の投稿の管理（issue #1902）
  class ProfileCorrectionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @unit = Unit.create!(key: 'correction-unit', name: '訂正ユニット', status: 'active')
      @person = Person.create!(key: 'correction-person', name: '訂正する人', status: :active)
      @unit_correction = ProfileCorrection.create!(target: @unit, correction: '結成日が違います',
                                                   source_url: 'https://example.com/unit', submitter_ip: '192.0.2.1')
      @person_correction = ProfileCorrection.create!(target: @person, correction: '誕生日が違います')
    end

    def login_as(user)
      post login_path, params: { email: user.email, password: 'password' }
    end

    test 'requires admin role' do
      login_as(users(:one))

      get admin_profile_corrections_path
      assert_redirected_to root_path

      patch resolve_admin_profile_correction_path(@unit_correction)
      assert_redirected_to root_path
      assert @unit_correction.reload.pending?
    end

    test 'index lists pending corrections and filters by target type and status' do
      login_as(users(:admin))

      get admin_profile_corrections_path
      assert_response :success
      assert_includes response.body, '結成日が違います'
      assert_includes response.body, '誕生日が違います'
      assert_includes response.body, '192.0.2.1'
      assert_select "a[href='#{edit_admin_unit_path(@unit)}']", text: 'ユニットを編集'
      assert_select "a[href='#{edit_admin_person_path(@person)}']", text: '個人を編集'

      get admin_profile_corrections_path(target_type: 'Person')
      assert_not_includes response.body, '結成日が違います'
      assert_includes response.body, '誕生日が違います'

      get admin_profile_corrections_path(status: 'resolved')
      assert_select 'td', text: '該当する投稿はありません'
    end

    test 'reject and resolve change the status' do
      login_as(users(:admin))

      patch reject_admin_profile_correction_path(@unit_correction)
      assert @unit_correction.reload.rejected?

      patch resolve_admin_profile_correction_path(@person_correction)
      assert @person_correction.reload.resolved?
    end

    test 'edit pages show pending corrections to admins only' do
      login_as(users(:admin))
      get edit_admin_unit_path(@unit)
      assert_select "form[action='#{resolve_admin_profile_correction_path(@unit_correction)}']"
      get edit_admin_person_path(@person)
      assert_select "form[action='#{resolve_admin_profile_correction_path(@person_correction)}']"

      delete logout_path
      login_as(users(:one))
      get edit_admin_unit_path(@unit)
      assert_select "form[action='#{resolve_admin_profile_correction_path(@unit_correction)}']", count: 0
    end
  end
end

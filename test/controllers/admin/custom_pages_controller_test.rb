# frozen_string_literal: true

require 'test_helper'

module Admin
  class CustomPagesControllerTest < ActionDispatch::IntegrationTest
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
    end

    test 'create allows setting old_key' do
      assert_difference('CustomPage.count') do
        post admin_custom_pages_path, params: {
          custom_page: { key: 'events', title: 'イベント', body: '本文', old_key: 'events' }
        }
      end

      assert_equal 'events', CustomPage.last.old_key
    end

    test 'update allows changing old_key' do
      custom_page = CustomPage.create!(key: 'events', title: 'イベント', old_key: 'old-value')

      patch admin_custom_page_path(custom_page), params: {
        custom_page: { old_key: '%B5%C1%B1%E7%B3%E8%C6%B0' }
      }

      assert_redirected_to edit_admin_custom_page_path(custom_page)
      custom_page.reload
      assert_equal '%B5%C1%B1%E7%B3%E8%C6%B0', custom_page.old_key
    end

    test 'index with system=only shows only system pages' do
      CustomPage.find_or_create_by!(key: 'footer') { |p| p.title = 'フッター' }
      CustomPage.create!(key: 'events', title: 'イベント')

      get admin_custom_pages_path(system: 'only')

      assert_includes @controller.view_assigns['custom_pages'].map(&:key), 'footer'
      assert_not_includes @controller.view_assigns['custom_pages'].map(&:key), 'events'
    end

    test 'index with system=exclude hides system pages' do
      CustomPage.find_or_create_by!(key: 'footer') { |p| p.title = 'フッター' }
      CustomPage.create!(key: 'events', title: 'イベント')

      get admin_custom_pages_path(system: 'exclude')

      assert_not_includes @controller.view_assigns['custom_pages'].map(&:key), 'footer'
      assert_includes @controller.view_assigns['custom_pages'].map(&:key), 'events'
    end
  end
end

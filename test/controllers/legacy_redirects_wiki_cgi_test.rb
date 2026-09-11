# frozen_string_literal: true

require 'test_helper'

# 旧wiki.cgi宛のリクエストの救済(issue #1482)
class LegacyRedirectsWikiCgiTest < ActionDispatch::IntegrationTest
  setup do
    @unit = Unit.create!(
      key: 'new_unit_key',
      name: 'Test Unit',
      old_key: 'old_unit_k',
      status: :active
    )
  end

  test 'page=... should redirect the same way as .html for a matching old_key' do
    get "/wiki.cgi?page=#{@unit.old_key}"
    assert_response :moved_permanently
    assert_redirected_to profile_path(@unit.key)
  end

  test 'page=... should return 404 if old_key not found' do
    get '/wiki.cgi?page=non_existent_key'
    assert_response :not_found
  end

  test 'date=...&action=DAY should redirect to the daily page' do
    get '/wiki.cgi?date=2008%2F10%2F24&action=DAY'
    assert_response :moved_permanently
    assert_redirected_to '/date/2008/10/24'
  end

  test 'with no recognizable params should return 404' do
    get '/wiki.cgi?foo=bar'
    assert_response :not_found
  end

  test 'date=...&action=DAY should return 404 for an unparseable date' do
    get '/wiki.cgi?date=not-a-date&action=DAY'
    assert_response :not_found
  end

  test 'date=... without action=DAY should return 404' do
    get '/wiki.cgi?date=2008%2F10%2F24'
    assert_response :not_found
  end
end

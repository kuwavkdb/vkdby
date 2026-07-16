# frozen_string_literal: true

require 'test_helper'

class LegacyRedirectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @unit = Unit.create!(
      key: 'new_unit_key',
      name: 'Test Unit',
      old_key: 'old_unit_k',
      status: :active
    )
    @person = Person.create!(
      key: 'new_person_key',
      name: 'Test Person',
      old_key: 'old_person_k',
      status: :active
    )
  end

  test 'should redirect to unit page if old_key matches unit' do
    get "/#{@unit.old_key}.html"
    assert_response :moved_permanently
    assert_redirected_to profile_path(@unit.key)
    assert_match(/<#{Regexp.escape(profile_url(@unit.key))}>; rel="canonical"/, response.headers['Link'])
  end

  test 'should redirect to person page if old_key matches person' do
    get "/#{@person.old_key}.html"
    assert_response :moved_permanently
    assert_redirected_to profile_path(@person.key)
    assert_match(/<#{Regexp.escape(profile_url(@person.key))}>; rel="canonical"/, response.headers['Link'])
  end

  test 'should redirect correctly for EUC-JP percent-encoded key' do
    # Create a unit with the specific EUC-JP encoded key
    # %B7%DF... corresponds to "月光花" in EUC-JP
    euc_key = '%B7%DF%B9%FC%C0%B8%CA%AA%B7%B2%BD%B8'
    unit = Unit.create!(
      key: 'gekkoka',
      name: '月光花',
      old_key: euc_key,
      status: :active
    )

    # Request with the percent-encoded URL (simulating curl/browser behavior)
    # The middleware should handle double-encoding if necessary
    get "/#{euc_key}.html"

    assert_response :moved_permanently
    assert_redirected_to profile_path(unit.key)
  end

  test 'should return 404 if old_key not found' do
    get '/non_existent_key.html'
    assert_response :not_found
  end

  test 'should redirect /NEWS.html to /trends' do
    get '/NEWS.html'
    assert_response :moved_permanently
    assert_redirected_to '/trends'
  end

  test 'should redirect /release_recent.htm to /items' do
    get '/release_recent.htm'
    assert_response :moved_permanently
    assert_redirected_to '/items'
  end

  test 'should redirect EUC-JP encoded index page to /units' do
    get '/%BA%F7%B0%FA.html'
    assert_response :moved_permanently
    assert_redirected_to '/units'
  end

  test 'should redirect EUC-JP encoded person index page to /people' do
    get '/%B8%C4%BF%CD%BA%F7%B0%FA.html'
    assert_response :moved_permanently
    assert_redirected_to '/people'
  end

  test 'should redirect EUC-JP encoded timeline page to /timeline' do
    get '/%C7%AF%C9%BD.html'
    assert_response :moved_permanently
    assert_redirected_to '/timeline'
  end

  test 'should redirect EUC-JP encoded timeline page with suffix to /timeline' do
    get '/%C7%AF%C9%BD2008.html'
    assert_response :moved_permanently
    assert_redirected_to '/timeline'
  end

  test 'should redirect double-percent-encoded yearly trend page to /date/:year' do
    get '/%C6%B0%B8%FE%252F2024.html'
    assert_response :moved_permanently
    assert_redirected_to '/date/2024'
  end
end

# frozen_string_literal: true

require 'test_helper'

# 旧URL（/{old_key}.html）から会場ページへの転送（issue #1691）
class LegacyRedirectsVenueTest < ActionDispatch::IntegrationTest
  test 'should redirect to venue page if old_key matches a venue' do
    venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', old_key: 'old_venue_k')
    get '/old_venue_k.html'
    assert_response :moved_permanently
    assert_redirected_to venue_path(venue.key)
    assert_match(/<#{Regexp.escape(venue_url(venue.key))}>; rel="canonical"/, response.headers['Link'])
  end

  test 'should redirect EUC-JP encoded venue old_key to venue page' do
    # %BF%B7%BD%C9LOFT は EUC-JP の「新宿LOFT」
    euc_key = '%BF%B7%BD%C9LOFT'
    venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', old_key: euc_key)
    get "/#{euc_key}.html"
    assert_response :moved_permanently
    assert_redirected_to venue_path(venue.key)
  end

  test 'should redirect to venue page if an alias old_key matches a venue' do
    venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', aliases: [{ 'name' => 'LOFT', 'old_key' => 'LOFT' }])
    get '/LOFT.html'
    assert_response :moved_permanently
    assert_redirected_to venue_path(venue.key)
  end

  test 'should redirect a merged venue old_key to the destination venue page' do
    destination = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT')
    merged = Venue.create!(key: 'loft-dup', name: 'ロフト', old_key: 'loft_dup', destination_key: destination.key)
    merged.discard
    get '/loft_dup.html'
    assert_response :moved_permanently
    assert_redirected_to venue_path(destination.key)
  end

  test 'should not redirect to a discarded venue' do
    venue = Venue.create!(key: 'closed-venue', name: '閉店した会場', old_key: 'closed_venue')
    venue.discard
    get '/closed_venue.html'
    assert_response :not_found
  end

  test 'should prefer unit over venue when old_key collides' do
    unit = Unit.create!(key: 'new_unit_key', name: 'Test Unit', old_key: 'old_unit_k', status: :active)
    Venue.create!(key: 'venue-collide', name: '会場', old_key: unit.old_key)
    get "/#{unit.old_key}.html"
    assert_response :moved_permanently
    assert_redirected_to profile_path(unit.key)
  end

  test 'should redirect to venue page when a unit with the same old_key is discarded' do
    unit = Unit.create!(key: '日本武道館', name: '日本武道館', old_key: 'budokan_old', status: :active)
    unit.discard
    venue = Venue.create!(key: 'nippon-budokan', name: '日本武道館', old_key: 'budokan_old')
    get '/budokan_old.html'
    assert_response :moved_permanently
    assert_redirected_to venue_path(venue.key)
  end

  test 'should redirect to venue page when a person with the same alias old_key is discarded' do
    person = Person.create!(key: 'budokan-person', name: '武道館', status: :active,
                            aliases: [{ 'name' => '武道館', 'old_key' => 'budokan_alias' }])
    person.discard
    venue = Venue.create!(key: 'nippon-budokan', name: '日本武道館', aliases: [{ 'name' => '武道館', 'old_key' => 'budokan_alias' }])
    get '/budokan_alias.html'
    assert_response :moved_permanently
    assert_redirected_to venue_path(venue.key)
  end

  test 'should still redirect a merged (discarded with destination_key) unit to its profile' do
    Venue.create!(key: 'nippon-budokan', name: '日本武道館', old_key: 'merged_old')
    merged = Unit.create!(key: 'merged-unit', name: '統合元', old_key: 'merged_old', status: :active,
                          destination_key: 'dest-unit')
    merged.discard
    get '/merged_old.html'
    assert_response :moved_permanently
    assert_redirected_to profile_path('merged-unit')
  end
end

# frozen_string_literal: true

require 'test_helper'

module Admin
  # 会場登録画面のURLパラメーターによる事前入力（venue-urlスキル、issue #1705）
  class VenuesPrefillTest < ActionDispatch::IntegrationTest
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
    end

    test 'new prefills basic attributes from venue params' do
      get new_admin_venue_path(venue: {
                                 name: 'Spotify O-EAST', name_kana: 'スポティファイオーイースト', key: 'o-east',
                                 venue_type: 'live_house', status: 'active', prefecture: '東京都', area: '渋谷',
                                 address: '東京都渋谷区道玄坂2-14-8', capacity: '1300', note: '最寄り: 渋谷駅'
                               })

      assert_response :success
      assert_select "input[name='venue[name]'][value='Spotify O-EAST']"
      assert_select "input[name='venue[name_kana]'][value='スポティファイオーイースト']"
      assert_select "input[name='venue[key]'][value='o-east']"
      assert_select "input[type=radio][name='venue[venue_type]'][value='live_house'][checked]"
      assert_select "select[name='venue[prefecture]'] option[selected][value='東京都']"
      assert_select "input[name='venue[area]'][value='渋谷']"
      assert_select "input[name='venue[address]'][value='東京都渋谷区道玄坂2-14-8']"
      assert_select "input[name='venue[capacity]'][value='1300']"
      assert_select "textarea[name='venue[note]']", text: /最寄り: 渋谷駅/
    end

    test 'new prefills links, aliases and name logs from short keys' do
      get new_admin_venue_path(venue: {
                                 name: 'Spotify O-EAST',
                                 links: { '0' => { text: '公式サイト', url: 'https://example.com/' } },
                                 aliases: { '0' => { name: 'O-EAST', kana: 'オーイースト' } },
                                 name_logs: { '0' => { name: 'SHIBUYA O-EAST', date: '2000' },
                                              '1' => { name: 'Spotify O-EAST', date: '2019-04' } }
                               })

      assert_response :success
      assert_select "input[name$='[text]'][value='公式サイト']"
      assert_select "input[name$='[url]'][value='https://example.com/']"
      assert_select "input[name='venue[aliases_attributes][0][name]'][value='O-EAST']"
      assert_select "input[name='venue[aliases_attributes][0][kana]'][value='オーイースト']"
      assert_select "input[name='venue[name_logs_attributes][0][name]'][value='SHIBUYA O-EAST']"
      assert_select "input[name='venue[name_logs_attributes][1][date]'][value='2019-04']"
    end

    test 'new ignores invalid enum, prefecture and capacity values instead of raising' do
      get new_admin_venue_path(venue: { name: 'テスト', venue_type: 'arena', status: 'open',
                                        prefecture: '東京', capacity: '約300' })

      assert_response :success
      assert_select "input[type=radio][name='venue[venue_type]'][value='live_house'][checked]"
      assert_select "input[type=radio][name='venue[status]'][value='active'][checked]"
      assert_select "select[name='venue[prefecture]'] option[selected][value]", count: 0
      assert_select "input[name='venue[capacity]']:not([value])"
    end

    test 'new does not accept attributes outside the prefill whitelist' do
      get new_admin_venue_path(venue: { name: 'テスト', old_key: 'injected', destination_key: 'other' })

      assert_response :success
      assert_select "input[name='venue[old_key]'][value='injected']", count: 0
      assert_select "input[name='venue[destination_key]'][value='other']", count: 0
    end

    test 'new without params renders an empty form' do
      get new_admin_venue_path

      assert_response :success
      assert_select "input[name='venue[name]']:not([value])"
    end

    test 'new lists existing venues whose name or alias matches the prefilled name' do
      existing = Venue.create!(key: 'o-east', name: 'Spotify O-EAST', aliases: [{ 'name' => 'O-EAST' }])
      Venue.create!(key: 'unrelated', name: '無関係の会場')

      get new_admin_venue_path(venue: { name: 'O-EAST' })

      assert_response :success
      assert_select "a[href='#{edit_admin_venue_path(existing)}']", text: 'Spotify O-EAST'
      assert_not_includes response.body, '無関係の会場'
    end

    test 'new does not show the similar venues notice without a name' do
      Venue.create!(key: 'o-east', name: 'Spotify O-EAST')

      get new_admin_venue_path

      assert_not_includes response.body, '一致しそうな会場'
    end
  end
end

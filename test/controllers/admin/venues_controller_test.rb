# frozen_string_literal: true

require 'test_helper'

module Admin
  class VenuesControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
    setup do
      @venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', prefecture: '東京都', area: '新宿',
                             aliases: [{ 'name' => 'ロフト' }])
    end

    def login_as(user)
      post login_path, params: { email: user.email, password: 'password' }
    end

    test 'requires login' do
      get admin_venues_path

      assert_redirected_to login_path
    end

    test 'index lists venues and searches by alias' do
      login_as(users(:one))
      Venue.create!(key: 'other', name: '別の会場')

      get admin_venues_path, params: { q: 'ロフト' }

      assert_response :success
      assert_includes response.body, '新宿LOFT'
      assert_not_includes response.body, '別の会場'
    end

    test 'index filters by prefecture and venue_type' do
      login_as(users(:one))
      Venue.create!(key: 'osaka-hall', name: '大阪のホール', prefecture: '大阪府', venue_type: :hall)

      get admin_venues_path, params: { prefecture: '大阪府', venue_type: 'hall' }

      assert_response :success
      assert_includes response.body, '大阪のホール'
      assert_not_includes response.body, '新宿LOFT'
    end

    test 'new renders the form' do
      login_as(users(:one))

      get new_admin_venue_path

      assert_response :success
    end

    test 'create saves a venue with name_log, aliases and links and records update logs' do
      login_as(users(:one))

      assert_difference(-> { Venue.count } => 1, -> { Link.count } => 1) do
        post admin_venues_path, params: {
          venue: {
            key: 'zepp-shinjuku', name: 'Zepp Shinjuku', name_kana: 'ゼップシンジュク', venue_type: 'hall',
            prefecture: '東京都', area: '新宿', address: '東京都新宿区歌舞伎町', capacity: '1500', status: 'active',
            note: 'メモ',
            name_logs_attributes: { '0' => { name: 'Zepp Shinjuku', name_kana: '', date: '2023-04' },
                                    '1' => { name: '', name_kana: '', date: '' } },
            aliases_attributes: { '0' => { name: 'ゼップ新宿', kana: '', old_key: '', hidden: '0' } },
            links_attributes: { '0' => { text: '公式サイト', url: 'https://example.com/' } }
          }
        }
      end

      venue = Venue.find_by!(key: 'zepp-shinjuku')
      assert_redirected_to edit_admin_venue_path(venue)
      assert venue.hall?
      assert_equal 1500, venue.capacity
      assert_equal [{ 'name' => 'Zepp Shinjuku', 'date' => '2023-04' }], venue.name_log
      assert_equal [{ 'name' => 'ゼップ新宿' }], venue[:aliases]
      assert_equal 'https://example.com/', venue.links.first.url
      assert UpdateLog.exists?(loggable: venue, action: 'create')
      assert UpdateLog.exists?(loggable: venue.links.first, action: 'create', subject: venue)
    end

    test 'create with invalid params re-renders the form' do
      login_as(users(:one))

      assert_no_difference('Venue.count') do
        post admin_venues_path, params: { venue: { key: '', name: '' } }
      end

      assert_response :unprocessable_entity
    end

    test 'edit renders the form' do
      login_as(users(:one))

      get edit_admin_venue_path(@venue)

      assert_response :success
      assert_includes response.body, '新宿LOFT'
    end

    test 'update changes attributes and records an update log' do
      login_as(users(:one))

      patch admin_venue_path(@venue), params: { venue: { capacity: '550', status: 'closed' } }

      assert_redirected_to edit_admin_venue_path(@venue)
      @venue.reload
      assert_equal 550, @venue.capacity
      assert @venue.closed?
      assert UpdateLog.exists?(loggable: @venue, action: 'update')
    end

    test 'update rejects an invalid name_log date' do
      login_as(users(:one))

      patch admin_venue_path(@venue), params: {
        venue: { name_logs_attributes: { '0' => { name: '旧名', date: '2001年' } } }
      }

      assert_response :unprocessable_entity
      assert_equal [], @venue.reload.name_log
    end

    test 'update can remove a link' do
      login_as(users(:one))
      link = @venue.links.create!(text: '公式', url: 'https://example.com/')

      assert_difference('Link.count', -1) do
        patch admin_venue_path(@venue), params: {
          venue: { links_attributes: { '0' => { id: link.id, text: '公式', url: link.url, _destroy: '1' } } }
        }
      end
      assert UpdateLog.exists?(loggable_type: 'Link', loggable_id: link.id, action: 'discard', subject: @venue)
    end

    test 'operator cannot discard a venue' do
      operator = User.create!(email: 'operator@example.com', name: 'Operator', password: 'password', role: :operator)
      login_as(operator)

      delete admin_venue_path(@venue)

      assert_redirected_to admin_root_path
      assert_not @venue.reload.discarded?
    end

    test 'super_operator can discard and undiscard a venue' do
      login_as(users(:one))

      delete admin_venue_path(@venue)
      assert_redirected_to admin_venues_path
      assert @venue.reload.discarded?

      patch undiscard_admin_venue_path(@venue)
      assert_redirected_to admin_venues_path
      assert_not @venue.reload.discarded?
    end

    test 'update ignores key' do
      login_as(users(:one))

      patch admin_venue_path(@venue), params: { venue: { key: 'hacked', name: '新宿LOFT（更新）' } }

      assert_redirected_to edit_admin_venue_path(@venue)
      @venue.reload
      assert_equal 'shinjuku-loft', @venue.key
      assert_equal '新宿LOFT（更新）', @venue.name
    end

    test 'change_key requires admin role' do
      login_as(users(:one))

      patch change_key_admin_venue_path(@venue), params: { new_key: 'loft' }

      assert_redirected_to root_path
      assert_equal 'shinjuku-loft', @venue.reload.key
    end

    test 'change_key changes the key and creates a redirect stub when admin' do
      login_as(users(:admin))

      assert_difference('Venue.with_discarded.count', 1) do
        patch change_key_admin_venue_path(@venue), params: { new_key: 'loft-shinjuku' }
      end

      assert_redirected_to edit_admin_venue_path(@venue)
      assert_equal 'loft-shinjuku', @venue.reload.key
      assert_equal 'loft-shinjuku', Venue.with_discarded.find_by!(key: 'shinjuku-loft').destination_key
      assert UpdateLog.exists?(loggable: @venue, action: 'change_key')
    end

    test 'change_key shows an error when the new key is already taken' do
      login_as(users(:admin))
      Venue.create!(key: 'taken', name: '別の会場')

      patch change_key_admin_venue_path(@venue), params: { new_key: 'taken' }

      assert_redirected_to edit_admin_venue_path(@venue)
      assert flash[:alert].present?
      assert_equal 'shinjuku-loft', @venue.reload.key
    end

    test 'index can list redirect sources' do
      login_as(users(:one))
      @venue.change_key!('loft-shinjuku')

      get admin_venues_path, params: { redirect_source: 'only' }

      assert_response :success
      assert_includes response.body, '→ loft-shinjuku'
    end

    test 'search returns kept venues matching name or alias as JSON' do
      login_as(users(:one))
      discarded = Venue.create!(key: 'closed-loft', name: 'ロフト跡地')
      discarded.discard

      get search_admin_venues_path, params: { q: 'ロフト' }

      assert_response :success
      json = response.parsed_body
      assert_equal [@venue.id], json.pluck('id')
      assert_equal '東京都 新宿', json.first['location']
    end

    test 'search excludes redirect stubs left by a key change' do
      login_as(users(:one))
      @venue.change_key!('loft-shinjuku')

      get search_admin_venues_path, params: { q: 'shinjuku' }

      assert_equal ['loft-shinjuku'], response.parsed_body.pluck('key')
    end
  end
end

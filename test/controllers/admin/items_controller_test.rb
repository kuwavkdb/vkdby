# frozen_string_literal: true

require 'test_helper'

module Admin
  class ItemsControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
    end

    test 'update accepts a name-only artist that has no matching unit/person record' do
      item = Item.create!(
        title: 'Test Item',
        release_date: Date.today,
        link_url: "https://example.com/item-#{SecureRandom.hex(4)}"
      )

      patch admin_item_path(item), params: {
        item: {
          title: item.title,
          release_date: item.release_date,
          link_url: item.link_url,
          artists_json: [{ name: '名称のみのアーティスト' }].to_json
        }
      }

      assert_redirected_to edit_admin_item_path(item)
      item.reload
      assert_equal [{ 'name' => '名称のみのアーティスト' }], item.artists
    end

    test 'update sets the various_artists flag from the checkbox param' do
      item = Item.create!(
        title: 'Test Item',
        release_date: Date.today,
        link_url: "https://example.com/item-#{SecureRandom.hex(4)}"
      )

      patch admin_item_path(item), params: {
        item: {
          title: item.title,
          release_date: item.release_date,
          link_url: item.link_url,
          various_artists: '1'
        }
      }

      assert_redirected_to edit_admin_item_path(item)
      assert item.reload.various_artists?
    end

    test 'new does not auto-confirm an artist passed via query params, even with an artist_key' do
      get new_admin_item_path, params: {
        artist_name: 'シド',
        artist_key: 'shid'
      }

      assert_response :success
      assert_match(/artist-search-input[^>]*value="シド"/, response.body)
      assert_no_match(/artist-name-hidden[^>]*value="シド"/, response.body)
    end

    test 'edit renders a previously saved name-only artist as a selected chip, not a blank search box' do
      item = Item.create!(
        title: 'Test Item',
        release_date: Date.today,
        link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
        artists: [{ 'name' => '名称のみのアーティスト' }]
      )

      get edit_admin_item_path(item)

      assert_response :success
      assert_match(/artist-name-hidden[^>]*value="名称のみのアーティスト"/, response.body)
    end

    test 'bulk_artist_edit renders the search form without a query' do
      get bulk_artist_edit_admin_items_path

      assert_response :success
      assert_includes response.body, '検索対象と検索値を指定して検索してください。'
    end

    test 'bulk_artist_edit lists only items whose artists match the given old_key' do
      matching = Item.create!(title: 'Matching Item', release_date: Date.today,
                              link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                              artists: [{ 'name' => 'ムック', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])
      other = Item.create!(title: 'Other Item', release_date: Date.today,
                           link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                           artists: [{ 'name' => 'Other Artist' }])

      get bulk_artist_edit_admin_items_path(match_type: 'old_key', match_value: '%A5%E0%A5%C3%A5%AF')

      assert_response :success
      assert_includes response.body, matching.title
      assert_not_includes response.body, other.title
      assert_includes response.body, 'onsubmit="return confirmBulkArtistUpdate()"'
      assert_includes response.body, 'function confirmBulkArtistUpdate()'
    end

    test 'bulk_artist_update replaces the matching artist on selected items only' do
      target = Item.create!(title: 'Target Item', release_date: Date.today,
                            link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                            artists: [{ 'name' => 'ムック', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])
      not_selected = Item.create!(title: 'Not Selected Item', release_date: Date.today,
                                  link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                                  artists: [{ 'name' => 'ムック', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])

      patch bulk_artist_update_admin_items_path, params: {
        ids: [target.id],
        match_type: 'old_key',
        match_value: '%A5%E0%A5%C3%A5%AF',
        replacement_json: [{ name: 'MUCC', key: 'mucc' }].to_json
      }

      assert_redirected_to bulk_artist_edit_admin_items_path(match_type: 'old_key', match_value: '%A5%E0%A5%C3%A5%AF')
      assert_equal '1件のアーティストを差し替えました', flash[:notice]
      assert_equal 'mucc', target.reload.artists.first['key']
      assert_nil not_selected.reload.artists.first['key']
    end

    test 'bulk_artist_update does not count or touch a selected item whose artist no longer matches' do
      target = Item.create!(title: 'Target Item', release_date: Date.today,
                            link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                            artists: [{ 'name' => 'ムック', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])
      # 検索後、送信前に別の操作で紐づけが変わってしまったケースを想定
      stale = Item.create!(title: 'Stale Item', release_date: Date.today,
                           link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                           artists: [{ 'name' => '別の名前', 'key' => 'already-fixed' }])
      original_updated_at = stale.updated_at

      patch bulk_artist_update_admin_items_path, params: {
        ids: [target.id, stale.id],
        match_type: 'old_key',
        match_value: '%A5%E0%A5%C3%A5%AF',
        replacement_json: [{ name: 'MUCC', key: 'mucc' }].to_json
      }

      assert_equal '1件のアーティストを差し替えました', flash[:notice]
      assert_equal 'mucc', target.reload.artists.first['key']
      stale.reload
      assert_equal 'already-fixed', stale.artists.first['key']
      assert_equal original_updated_at, stale.updated_at
    end

    test 'bulk_artist_update shows an alert when no ids are selected' do
      patch bulk_artist_update_admin_items_path, params: {
        ids: [],
        match_type: 'old_key',
        match_value: 'x',
        replacement_json: [{ name: 'MUCC', key: 'mucc' }].to_json
      }

      assert_redirected_to bulk_artist_edit_admin_items_path(match_type: 'old_key', match_value: 'x')
      assert_equal '項目が選択されていません', flash[:alert]
    end

    test 'bulk_artist_update shows an alert when no replacement is selected' do
      item = Item.create!(title: 'Target Item', release_date: Date.today,
                          link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                          artists: [{ 'name' => 'ムック', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])

      patch bulk_artist_update_admin_items_path, params: {
        ids: [item.id],
        match_type: 'old_key',
        match_value: '%A5%E0%A5%C3%A5%AF',
        replacement_json: '[]'
      }

      assert_redirected_to bulk_artist_edit_admin_items_path(match_type: 'old_key', match_value: '%A5%E0%A5%C3%A5%AF')
      assert_equal '置換先のUnit/Personを選択してください', flash[:alert]
      assert_nil item.reload.artists.first['key']
    end

    test 'bulk_artist_edit requires super_operator role' do
      delete logout_path
      operator = User.create!(email: 'operator-bulk-artist-test@example.com', name: 'Operator', password: 'password', role: :operator)
      post login_path, params: { email: operator.email, password: 'password' }

      get bulk_artist_edit_admin_items_path(match_type: 'old_key', match_value: 'x')

      assert_redirected_to admin_root_path
    end
  end
end

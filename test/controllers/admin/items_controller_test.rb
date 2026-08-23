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

    test 'edit shows a 論理削除 button for admin on a kept item' do
      delete logout_path
      post login_path, params: { email: users(:admin).email, password: 'password' }
      item = Item.create!(title: 'Test Item', release_date: Date.today,
                          link_url: "https://example.com/item-#{SecureRandom.hex(4)}")

      get edit_admin_item_path(item)

      assert_response :success
      assert_includes response.body, '論理削除'
      assert_not_includes response.body, '復元'
    end

    test 'edit shows a 復元 button for admin on a discarded item' do
      delete logout_path
      post login_path, params: { email: users(:admin).email, password: 'password' }
      item = Item.create!(title: 'Test Item', release_date: Date.today,
                          link_url: "https://example.com/item-#{SecureRandom.hex(4)}")
      item.discard

      get edit_admin_item_path(item)

      assert_response :success
      assert_includes response.body, '復元'
    end

    test 'edit does not show the 論理削除 button for a non-admin' do
      item = Item.create!(title: 'Test Item', release_date: Date.today,
                          link_url: "https://example.com/item-#{SecureRandom.hex(4)}")

      get edit_admin_item_path(item)

      assert_response :success
      assert_not_includes response.body, '論理削除'
    end

    test 'index does not show the bulk artist replace UI without an artist search condition' do
      Item.create!(title: 'Some Item', release_date: Date.today,
                   link_url: "https://example.com/item-#{SecureRandom.hex(4)}")

      get admin_items_path

      assert_response :success
      assert_not_includes response.body, 'function confirmBulkArtistUpdate()'
      assert_not_includes response.body, 'row-check'
    end

    test 'index lists only items whose artists match the given old_key, and shows the bulk replace UI' do
      matching = Item.create!(title: 'Matching Item', release_date: Date.today,
                              link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                              artists: [{ 'name' => 'ムック', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])
      other = Item.create!(title: 'Other Item', release_date: Date.today,
                           link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                           artists: [{ 'name' => 'Other Artist' }])

      get admin_items_path(match_type: 'old_key', match_value: '%A5%E0%A5%C3%A5%AF')

      assert_response :success
      assert_includes response.body, matching.title
      assert_not_includes response.body, other.title
      assert_includes response.body, 'onsubmit="return confirmBulkArtistUpdate()"'
      assert_includes response.body, 'function confirmBulkArtistUpdate()'
    end

    test 'index marks the checkbox as unlinked only when the matching artist entry has no key' do
      unlinked = Item.create!(title: 'Unlinked Item', release_date: Date.today,
                              link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                              artists: [{ 'name' => 'ムック', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])
      linked = Item.create!(title: 'Linked Item', release_date: Date.today,
                            link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                            artists: [{ 'name' => 'ムック', 'key' => 'mucc', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])

      get admin_items_path(match_type: 'old_key', match_value: '%A5%E0%A5%C3%A5%AF')

      assert_response :success
      assert_includes response.body, "id=\"item_#{unlinked.id}\" value=\"#{unlinked.id}\" class=\"row-check rounded border-gray-300\" data-unlinked=\"true\""
      assert_includes response.body, "id=\"item_#{linked.id}\" value=\"#{linked.id}\" class=\"row-check rounded border-gray-300\" data-unlinked=\"false\""
      assert_includes response.body, 'function selectUnlinkedArtistsOnly()'
    end

    test 'index lists only items whose artists match the given alias (display name)' do
      matching = Item.create!(title: 'Matching Item', release_date: Date.today,
                              link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                              artists: [{ 'name' => 'ムック', 'alias' => 'MUCC' }])
      other = Item.create!(title: 'Other Item', release_date: Date.today,
                           link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                           artists: [{ 'name' => 'ムック' }])

      get admin_items_path(match_type: 'alias', match_value: 'MUCC')

      assert_response :success
      assert_includes response.body, matching.title
      assert_not_includes response.body, other.title
    end

    test 'index shows both name and alias for each artist' do
      Item.create!(title: 'Matching Item', release_date: Date.today,
                   link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                   artists: [{ 'name' => 'ムック', 'alias' => 'MUCC' }])

      get admin_items_path

      assert_response :success
      assert_includes response.body, 'ムック（MUCC）'
    end

    test 'index shows name, alias, key and old_key separately for each artist in the bulk artist search results' do
      Item.create!(title: 'Matching Item', release_date: Date.today,
                   link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                   artists: [{ 'name' => 'ムック', 'alias' => 'MUCC', 'key' => 'mucc', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])

      get admin_items_path(match_type: 'alias', match_value: 'MUCC')

      assert_response :success
      assert_match(%r{>name</span>\s*<span[^>]*>ムック</span>}, response.body)
      assert_match(%r{>alias</span>\s*<span[^>]*>MUCC</span>}, response.body)
      assert_match(%r{>key</span>\s*<a[^>]*>mucc</a>}, response.body)
      assert_match(%r{>old_key</span>\s*<a[^>]*>%A5%E0%A5%C3%A5%AF</a>}, response.body)
    end

    test 'index links key to the profile page and old_key to the old wiki page' do
      Item.create!(title: 'Matching Item', release_date: Date.today,
                   link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                   artists: [{ 'name' => 'ムック', 'key' => 'mucc', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])

      get admin_items_path(match_type: 'key', match_value: 'mucc')

      assert_response :success
      assert_match(%r{<a[^>]*href="/mucc"[^>]*>mucc</a>}, response.body)
      assert_match(%r{<a[^>]*href="#{Regexp.escape(Rails.application.config.old_key_url_base)}/%A5%E0%A5%C3%A5%AF\.html"[^>]*>%A5%E0%A5%C3%A5%AF</a>},
                   response.body)
    end

    test 'index shows an em dash for key/old_key when the artist entry has neither' do
      Item.create!(title: 'Unlinked Item', release_date: Date.today,
                   link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                   artists: [{ 'name' => 'ムック' }])

      get admin_items_path(match_type: 'name', match_value: 'ムック')

      assert_response :success
      assert_match(%r{>key</span>\s*<span[^>]*>—</span>}, response.body)
      assert_match(%r{>old_key</span>\s*<span[^>]*>—</span>}, response.body)
    end

    test 'index does not show the bulk artist replace UI for an operator, even with an artist search condition' do
      delete logout_path
      operator = User.create!(email: 'operator-bulk-artist-test@example.com', name: 'Operator', password: 'password', role: :operator)
      post login_path, params: { email: operator.email, password: 'password' }
      Item.create!(title: 'Matching Item', release_date: Date.today,
                   link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                   artists: [{ 'name' => 'ムック', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])

      get admin_items_path(match_type: 'old_key', match_value: '%A5%E0%A5%C3%A5%AF')

      assert_response :success
      assert_not_includes response.body, 'function confirmBulkArtistUpdate()'
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

      assert_redirected_to admin_items_path(match_type: 'old_key', match_value: '%A5%E0%A5%C3%A5%AF')
      assert_equal '1件のアーティストを差し替えました', flash[:notice]
      assert_equal 'mucc', target.reload.artists.first['key']
      assert_nil not_selected.reload.artists.first['key']
    end

    test 'bulk_artist_update applies the specified display name (alias) to the replaced artist' do
      target = Item.create!(title: 'Target Item', release_date: Date.today,
                            link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                            artists: [{ 'name' => 'ムック', 'alias' => 'OLD ALIAS', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])

      patch bulk_artist_update_admin_items_path, params: {
        ids: [target.id],
        match_type: 'old_key',
        match_value: '%A5%E0%A5%C3%A5%AF',
        replacement_json: [{ name: 'MUCC', key: 'mucc', alias: 'MUCC (表示名)' }].to_json
      }

      assert_equal 'MUCC (表示名)', target.reload.artists.first['alias']
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

      assert_redirected_to admin_items_path(match_type: 'old_key', match_value: 'x')
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

      assert_redirected_to admin_items_path(match_type: 'old_key', match_value: '%A5%E0%A5%C3%A5%AF')
      assert_equal '置換先のUnit/Personを選択してください', flash[:alert]
      assert_nil item.reload.artists.first['key']
    end

    test 'destroy soft-deletes the item instead of destroying the record' do
      delete logout_path
      post login_path, params: { email: users(:admin).email, password: 'password' }
      item = Item.create!(title: 'Target Item', release_date: Date.today,
                          link_url: "https://example.com/item-#{SecureRandom.hex(4)}")

      delete admin_item_path(item)

      assert_redirected_to admin_items_path
      assert item.reload.discarded?
      assert Item.with_discarded.exists?(item.id)
    end

    test 'destroy requires admin role' do
      item = Item.create!(title: 'Target Item', release_date: Date.today,
                          link_url: "https://example.com/item-#{SecureRandom.hex(4)}")

      delete admin_item_path(item)

      assert_redirected_to root_path
      assert_not item.reload.discarded?
    end

    test 'undiscard restores a discarded item' do
      delete logout_path
      post login_path, params: { email: users(:admin).email, password: 'password' }
      item = Item.create!(title: 'Target Item', release_date: Date.today,
                          link_url: "https://example.com/item-#{SecureRandom.hex(4)}")
      item.discard

      patch undiscard_admin_item_path(item)

      assert_redirected_to admin_items_path
      assert_not item.reload.discarded?
    end

    test 'index does not show discarded items by default' do
      kept = Item.create!(title: 'Kept Item', release_date: Date.today,
                          link_url: "https://example.com/item-#{SecureRandom.hex(4)}")
      discarded = Item.create!(title: 'Discarded Item', release_date: Date.today,
                               link_url: "https://example.com/item-#{SecureRandom.hex(4)}")
      discarded.discard

      get admin_items_path

      assert_response :success
      assert_includes response.body, kept.title
      assert_not_includes response.body, discarded.title
    end

    test 'index with discarded=only shows only discarded items' do
      kept = Item.create!(title: 'Kept Item', release_date: Date.today,
                          link_url: "https://example.com/item-#{SecureRandom.hex(4)}")
      discarded = Item.create!(title: 'Discarded Item', release_date: Date.today,
                               link_url: "https://example.com/item-#{SecureRandom.hex(4)}")
      discarded.discard

      get admin_items_path(discarded: 'only')

      assert_response :success
      assert_includes response.body, discarded.title
      assert_not_includes response.body, kept.title
    end

    test 'bulk_artist_update requires super_operator role' do
      delete logout_path
      operator = User.create!(email: 'operator-bulk-artist-test@example.com', name: 'Operator', password: 'password', role: :operator)
      post login_path, params: { email: operator.email, password: 'password' }
      item = Item.create!(title: 'Target Item', release_date: Date.today,
                          link_url: "https://example.com/item-#{SecureRandom.hex(4)}",
                          artists: [{ 'name' => 'ムック', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])

      patch bulk_artist_update_admin_items_path, params: {
        ids: [item.id],
        match_type: 'old_key',
        match_value: '%A5%E0%A5%C3%A5%AF',
        replacement_json: [{ name: 'MUCC', key: 'mucc' }].to_json
      }

      assert_redirected_to admin_root_path
      assert_nil item.reload.artists.first['key']
    end
  end
end

# frozen_string_literal: true

require 'test_helper'

module Admin
  class ItemsControllerTest < ActionDispatch::IntegrationTest
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
  end
end

# frozen_string_literal: true

require 'test_helper'

module Admin
  # 会場の編集画面から公開ページへのリンク（issue #1787）
  class VenuesPublicLinkTest < ActionDispatch::IntegrationTest
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
    end

    test 'edit links to the public venue page' do
      venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT')

      get edit_admin_venue_path(venue)

      assert_response :success
      assert_select "a[href='#{venue_path('shinjuku-loft')}']", text: '公開ページを見る'
    end

    test 'edit of a redirect source links to the destination venue page' do
      destination = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT')
      source = Venue.create!(key: 'loft-old', name: '旧ロフト', destination_key: destination.key)
      source.discard

      get edit_admin_venue_path(source)

      assert_response :success
      assert_select "a[href='#{venue_path('shinjuku-loft')}']", text: '転送先の公開ページを見る'
    end

    test 'edit of a discarded venue does not link to the public page' do
      venue = Venue.create!(key: 'closed-venue', name: '削除した会場')
      venue.discard

      get edit_admin_venue_path(venue)

      assert_response :success
      assert_select "a[href='#{venue_path('closed-venue')}']", count: 0
      assert_select 'a', text: /公開ページを見る/, count: 0
    end
  end
end

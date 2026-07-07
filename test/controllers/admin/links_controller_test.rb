# frozen_string_literal: true

require 'test_helper'

module Admin
  class LinksControllerTest < ActionDispatch::IntegrationTest
    setup do
      post login_path, params: { email: users(:one).email, password: 'password' }
      @unit = units(:one)
      @link_one = @unit.links.create!(url: 'https://example.com/a', sort_order: 1)
      @link_two = @unit.links.create!(url: 'https://example.com/b', sort_order: 2)
    end

    test 'should reorder links' do
      patch reorder_admin_links_path, params: {
        linkable_type: 'Unit',
        linkable_id: @unit.id,
        ids: [@link_two.id, @link_one.id]
      }, as: :json

      assert_response :success
      assert_equal 1, @link_two.reload.sort_order
      assert_equal 2, @link_one.reload.sort_order
    end

    test 'should reject invalid linkable_type' do
      patch reorder_admin_links_path, params: {
        linkable_type: 'Wikipage',
        linkable_id: @unit.id,
        ids: [@link_one.id]
      }, as: :json

      assert_response :bad_request
    end
  end
end

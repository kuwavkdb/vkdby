# frozen_string_literal: true

require 'test_helper'

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test '404 page shows the inline Google custom search widget' do
    get '/pages/this-key-does-not-exist-errors-controller-test'

    assert_response :not_found
    assert_includes response.body, 'ページが見つかりません'
    assert_includes response.body, '<div class="gcse-search">'
    assert_match(%r{cse\.google\.com/cse\.js\?cx=}, response.body)
  end
end

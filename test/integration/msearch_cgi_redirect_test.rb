# frozen_string_literal: true

require 'test_helper'

# 旧サイトの全文検索CGI(msearch.cgi)宛のリクエストを新しい検索ページへ
# 救済リダイレクトする(issue #1481)
class MsearchCgiRedirectTest < ActionDispatch::IntegrationTest
  test 'msearch.cgiへのリクエストは/searchへ301リダイレクトされる' do
    get '/search/msearch.cgi'

    assert_response :moved_permanently
    assert_redirected_to '/search'
  end

  test 'クエリパラメータは維持したまま/searchへリダイレクトされる' do
    get '/search/msearch.cgi?word=VAMPS'

    assert_response :moved_permanently
    assert_redirected_to '/search?word=VAMPS'
  end
end

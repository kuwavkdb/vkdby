require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get login_url
    assert_response :success
  end

  test "should login" do
    post login_url, params: { email: "one@example.com", password: "password" }
    assert_redirected_to root_url
  end

  test "should get destroy" do
    delete logout_url
    assert_redirected_to root_url
  end
end

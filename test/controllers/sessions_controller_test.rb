# frozen_string_literal: true

require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test 'should get new' do
    get login_url
    assert_response :success
  end

  test 'should login' do
    post login_url, params: { email: 'one@example.com', password: 'password' }
    assert_redirected_to root_url
  end

  test 'should redirect back to the page that required login' do
    get admin_root_url
    assert_redirected_to login_url

    post login_url, params: { email: 'one@example.com', password: 'password' }
    assert_redirected_to admin_root_url
  end

  test 'should redirect back to return_to param passed to the login page' do
    get login_url, params: { return_to: '/password/edit' }
    post login_url, params: { email: 'one@example.com', password: 'password' }
    assert_redirected_to edit_password_url
  end

  test 'should ignore an external return_to to avoid open redirect' do
    get login_url, params: { return_to: '//evil.example.com' }
    post login_url, params: { email: 'one@example.com', password: 'password' }
    assert_redirected_to root_url
  end

  test 'should ignore a return_to that hides a protocol-relative host behind a tab character' do
    get login_url, params: { return_to: "/\t/evil.example.com" }
    post login_url, params: { email: 'one@example.com', password: 'password' }
    assert_redirected_to root_url
  end

  test 'should ignore an overly long return_to to avoid session cookie overflow' do
    get login_url, params: { return_to: "/#{'a' * 5000}" }
    post login_url, params: { email: 'one@example.com', password: 'password' }
    assert_redirected_to root_url
  end

  test 'should get destroy' do
    delete logout_url
    assert_redirected_to root_url
  end

  test 'should redirect back to the page that had the logout button' do
    delete logout_url, params: { return_to: '/password/edit' }
    assert_redirected_to edit_password_url
  end

  test 'should ignore an external return_to on logout to avoid open redirect' do
    delete logout_url, params: { return_to: '//evil.example.com' }
    assert_redirected_to root_url
  end

  test 'should ignore a logout return_to that hides a protocol-relative host behind a tab character' do
    delete logout_url, params: { return_to: "/\t/evil.example.com" }
    assert_redirected_to root_url
  end
end

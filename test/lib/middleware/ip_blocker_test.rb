# frozen_string_literal: true

require 'test_helper'
require 'middleware/ip_blocker'

class IpBlockerTest < ActiveSupport::TestCase
  setup do
    @app = ->(_env) { [200, {}, ['OK']] }
    @middleware = Middleware::IpBlocker.new(@app)
  end

  test 'ブロック対象のIPからのリクエストは403を返す' do
    page = custom_pages(:blocking_ip_address)
    page.update!(body: "192.168.1.100\n10.0.0.1\n")

    # キャッシュをクリア
    @middleware.instance_variable_set(:@cached_at, nil)

    env = { 'REMOTE_ADDR' => '192.168.1.100', 'PATH_INFO' => '/', 'REQUEST_METHOD' => 'GET' }
    status, _headers, _body = @middleware.call(env)
    assert_equal 403, status
  end

  test 'ブロック対象外のIPからのリクエストは通過する' do
    page = custom_pages(:blocking_ip_address)
    page.update!(body: "192.168.1.100\n")

    @middleware.instance_variable_set(:@cached_at, nil)

    env = { 'REMOTE_ADDR' => '10.0.0.1', 'PATH_INFO' => '/', 'REQUEST_METHOD' => 'GET' }
    status, _headers, _body = @middleware.call(env)
    assert_equal 200, status
  end

  test '取り消し線付きのIPはブロックしない' do
    page = custom_pages(:blocking_ip_address)
    page.update!(body: "~~192.168.1.100~~\n10.0.0.1\n")

    @middleware.instance_variable_set(:@cached_at, nil)

    env = { 'REMOTE_ADDR' => '192.168.1.100', 'PATH_INFO' => '/', 'REQUEST_METHOD' => 'GET' }
    status, _headers, _body = @middleware.call(env)
    assert_equal 200, status
  end

  test '取り消し線なしのIPはブロックする' do
    page = custom_pages(:blocking_ip_address)
    page.update!(body: "~~192.168.1.100~~\n10.0.0.1\n")

    @middleware.instance_variable_set(:@cached_at, nil)

    env = { 'REMOTE_ADDR' => '10.0.0.1', 'PATH_INFO' => '/', 'REQUEST_METHOD' => 'GET' }
    status, _headers, _body = @middleware.call(env)
    assert_equal 403, status
  end

  test 'カスタムページが存在しない場合は通過する' do
    CustomPage.where(key: 'blocking_ip_address').destroy_all

    @middleware.instance_variable_set(:@cached_at, nil)

    env = { 'REMOTE_ADDR' => '192.168.1.100', 'PATH_INFO' => '/', 'REQUEST_METHOD' => 'GET' }
    status, _headers, _body = @middleware.call(env)
    assert_equal 200, status
  end

  test 'カスタムページが非公開（active: false）でもブロックが適用される' do
    page = CustomPage.find_or_create_by!(key: 'blocking_ip_address') do |p|
      p.title = 'IP Blocker'
      p.active = false
    end
    page.update!(body: "192.168.1.100\n", active: false)

    @middleware.instance_variable_set(:@cached_at, nil)

    env = { 'REMOTE_ADDR' => '192.168.1.100', 'PATH_INFO' => '/', 'REQUEST_METHOD' => 'GET' }
    status, _headers, _body = @middleware.call(env)
    assert_equal 403, status
  end

  private

  def custom_pages(name)
    CustomPage.find_or_create_by!(key: 'blocking_ip_address') do |p|
      p.title = 'IP Blocker'
      p.active = false
    end
  end
end

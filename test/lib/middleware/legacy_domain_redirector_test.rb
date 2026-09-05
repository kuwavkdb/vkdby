# frozen_string_literal: true

require 'test_helper'
require 'middleware/legacy_domain_redirector'

class LegacyDomainRedirectorTest < ActiveSupport::TestCase
  setup do
    @app = ->(_env) { [200, {}, ['OK']] }
    @middleware = Middleware::LegacyDomainRedirector.new(@app)
  end

  test 'next.vkdb.jpへのアクセスはパスとクエリ文字列を保持したまま本番ドメインへ301リダイレクトされる' do
    env = build_env(host: 'next.vkdb.jp', path: '/xxx', query: 'q=yyy')
    status, headers, = @middleware.call(env)

    assert_equal 301, status
    assert_equal 'https://www.vkdb.jp/xxx?q=yyy', headers['Location']
  end

  test 'vkdby.onrender.comへのアクセスは本番ドメインへ301リダイレクトされる' do
    env = build_env(host: 'vkdby.onrender.com', path: '/xxx', query: 'q=yyy')
    status, headers, = @middleware.call(env)

    assert_equal 301, status
    assert_equal 'https://www.vkdb.jp/xxx?q=yyy', headers['Location']
  end

  test '本番ドメイン（www.vkdb.jp）へのアクセスはリダイレクトされない' do
    env = build_env(host: 'www.vkdb.jp', path: '/xxx')
    status, = @middleware.call(env)

    assert_equal 200, status
  end

  test '対象外のホストへのアクセスはリダイレクトされない' do
    env = build_env(host: 'localhost', path: '/xxx')
    status, = @middleware.call(env)

    assert_equal 200, status
  end

  test '環境変数LEGACY_DOMAIN_REDIRECT_ENABLEDがfalseの場合はリダイレクトしない' do
    with_env('LEGACY_DOMAIN_REDIRECT_ENABLED' => 'false') do
      env = build_env(host: 'next.vkdb.jp', path: '/xxx')
      status, = @middleware.call(env)

      assert_equal 200, status
    end
  end

  private

  def build_env(host:, path:, query: nil)
    {
      'REQUEST_METHOD' => 'GET',
      'HTTP_HOST' => host,
      'SERVER_NAME' => host,
      'PATH_INFO' => path,
      'QUERY_STRING' => query.to_s,
      'rack.url_scheme' => 'https'
    }
  end

  def with_env(vars)
    original = vars.keys.to_h { |key| [key, ENV[key]] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end
end

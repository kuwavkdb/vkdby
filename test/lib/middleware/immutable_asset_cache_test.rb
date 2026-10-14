# frozen_string_literal: true

require 'test_helper'
require 'middleware/immutable_asset_cache'

# issue #1862: 1年・immutable のキャッシュ指定は digest 付きのアセットだけに付け、robots.txt などには付けない
class ImmutableAssetCacheTest < ActiveSupport::TestCase
  SHORT = 'public, max-age=3600'

  def call(path, status: 200, headers: { 'cache-control' => SHORT })
    app = ->(_env) { [status, headers, ['body']] }
    Middleware::ImmutableAssetCache.new(app).call(Rack::MockRequest.env_for(path))
  end

  test '正常に返せたアセットには1年・immutableを付ける' do
    _, headers, = call('/assets/tailwind-720d1a31.css')

    assert_equal "public, max-age=#{1.year.to_i}, immutable", headers['cache-control']
  end

  test '既存のCache-Controlは大文字小文字を問わず置き換える' do
    _, headers, = call('/assets/application-720d1a31.js', headers: { 'Cache-Control' => SHORT })

    assert_equal "public, max-age=#{1.year.to_i}, immutable", headers['cache-control']
    assert_not headers.key?('Cache-Control')
  end

  test 'robots.txt などアセット以外のファイルのキャッシュ指定は変えない' do
    %w[/robots.txt /ads.txt /favicon.ico /404.html].each do |path|
      _, headers, = call(path)

      assert_equal SHORT, headers['cache-control'], path
    end
  end

  test 'アセットへのエラー応答には付けない' do
    _, headers, = call('/assets/tailwind-00000000.css', status: 404, headers: { 'content-type' => 'text/html' })

    assert_nil headers['cache-control']
  end
end

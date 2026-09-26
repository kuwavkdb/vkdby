# frozen_string_literal: true

require 'test_helper'
require 'middleware/asset_error_no_store'

# issue #1698: デプロイ中に取得に失敗したアセット（404のHTML）がブラウザ・CDNに残らないようにする
class AssetErrorNoStoreTest < ActiveSupport::TestCase
  def call(path, status:, headers: {})
    app = ->(_env) { [status, headers, ['body']] }
    Middleware::AssetErrorNoStore.new(app).call(Rack::MockRequest.env_for(path))
  end

  test '存在しないアセットへの404にはno-storeを付ける' do
    status, headers, = call('/assets/tailwind-00000000.css', status: 404, headers: { 'content-type' => 'text/html' })

    assert_equal 404, status
    assert_equal 'no-store', headers['cache-control']
  end

  test '既存のCache-Controlは大文字小文字を問わず置き換える' do
    _, headers, = call('/assets/application-00000000.js', status: 404,
                                                          headers: { 'Cache-Control' => 'public, max-age=31536000' })

    assert_equal 'no-store', headers['cache-control']
    assert_not headers.key?('Cache-Control')
  end

  test 'アセットへの5xxにもno-storeを付ける' do
    _, headers, = call('/assets/tailwind-00000000.css', status: 503)

    assert_equal 'no-store', headers['cache-control']
  end

  test '正常に返せたアセットのキャッシュ指定は変えない' do
    immutable = 'public, max-age=31556952, immutable'
    _, headers, = call('/assets/tailwind-720d1a31.css', status: 200, headers: { 'cache-control' => immutable })

    assert_equal immutable, headers['cache-control']
  end

  test 'アセット以外のパスのエラーには手を入れない' do
    _, headers, = call('/no-such-page', status: 404, headers: { 'content-type' => 'text/html' })

    assert_nil headers['cache-control']
  end

  test 'ミドルウェアスタックの最も外側に置かれている' do
    assert_equal Middleware::AssetErrorNoStore, Rails.application.middleware.first.klass
  end
end

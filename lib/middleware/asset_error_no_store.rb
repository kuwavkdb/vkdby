# frozen_string_literal: true

module Middleware
  # 存在しないアセット（/assets/*）へのエラー応答に Cache-Control: no-store を付ける（issue #1698）。
  #
  # デプロイの切り替わり中は、新しいインスタンスが返したHTML（新しいdigestのCSSを参照）に続く
  # アセットのリクエストが、そのファイルを持たない旧インスタンスに届き、404のHTML（text/html）が
  # 返ることがある。この応答にはキャッシュの指定がないため、ブラウザやCloudflareに残ると
  # 「MIME type ('text/html') is not a supported stylesheet MIME type」でスタイルが当たらない
  # 状態が続く。digest付きのURLは中身が変わらない前提（immutable）なので、失敗した応答だけは
  # どこにも保存させないようにする。
  class AssetErrorNoStore
    ASSET_PATH_PREFIX = '/assets/'

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      return [status, headers, body] unless status.to_i >= 400 && asset_path?(env)

      headers.each_key.select { |key| key.to_s.casecmp?('cache-control') }.each { |key| headers.delete(key) }
      headers['cache-control'] = 'no-store'
      [status, headers, body]
    end

    private

    def asset_path?(env)
      env['PATH_INFO'].to_s.start_with?(ASSET_PATH_PREFIX)
    end
  end
end

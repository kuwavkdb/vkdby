# frozen_string_literal: true

module Middleware
  # digest 付きのアセット（/assets/*）の正常な応答だけに、1年・immutable のキャッシュ指定を付ける（issue #1862）。
  #
  # config.public_file_server.headers は public/ の下のファイル全部に同じヘッダーを付け、パスごとに分けられない。
  # robots.txt・ads.txt・ファビコン・エラーページなどは、ファイル名を変えずに中身を書き換えるため、
  # 1年・immutable にするとブラウザやCDN、クローラーに古い内容が残り続ける。そこで public_file_server.headers は
  # 短い期間にしておき、ファイル名が変わる /assets/ だけをここで長い期間に置き換える。
  # 失敗した応答（4xx・5xx）は AssetErrorNoStore（issue #1698）に任せ、ここでは触らない。
  class ImmutableAssetCache
    ASSET_PATH_PREFIX = '/assets/'
    CACHE_CONTROL = "public, max-age=#{1.year.to_i}, immutable".freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      return [status, headers, body] unless (200..299).cover?(status.to_i) && asset_path?(env)

      headers.each_key.select { |key| key.to_s.casecmp?('cache-control') }.each { |key| headers.delete(key) }
      headers['cache-control'] = CACHE_CONTROL
      [status, headers, body]
    end

    private

    def asset_path?(env)
      env['PATH_INFO'].to_s.start_with?(ASSET_PATH_PREFIX)
    end
  end
end

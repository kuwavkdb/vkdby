# frozen_string_literal: true

module Middleware
  # 本番切り替え前の検証用ドメイン（next.vkdb.jp）とRenderのデフォルトドメイン
  # （vkdby.onrender.com）へのアクセスを、本番の正規ドメイン（www.vkdb.jp）へ
  # 301リダイレクトする（issue #1381）。
  #
  # vkdb.jp（apex）はCloudflare側の設定で既に www.vkdb.jp へ302リダイレクトされる
  # ため、二重リダイレクトを避けてここでは直接 www.vkdb.jp を宛先にする。
  #
  # 何か問題が起きた場合に再デプロイなしで切り戻せるよう、環境変数
  # LEGACY_DOMAIN_REDIRECT_ENABLED（デフォルト有効）で無効化できるようにしている。
  class LegacyDomainRedirector
    REDIRECT_SOURCE_HOSTS = %w[next.vkdb.jp vkdby.onrender.com].freeze
    REDIRECT_TARGET_HOST = 'www.vkdb.jp'

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)

      return @app.call(env) unless enabled?
      return @app.call(env) unless REDIRECT_SOURCE_HOSTS.include?(request.host)

      redirect_response(request)
    end

    private

    def enabled?
      ENV.fetch('LEGACY_DOMAIN_REDIRECT_ENABLED', 'true') != 'false'
    end

    def redirect_response(request)
      location = "https://#{REDIRECT_TARGET_HOST}#{request.fullpath}"
      [301, { 'Location' => location, 'Content-Type' => 'text/plain' }, ["Redirecting to #{location}"]]
    end
  end
end

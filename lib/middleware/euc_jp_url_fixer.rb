# frozen_string_literal: true

require 'cgi'

module Middleware
  class EucJpUrlFixer
    def initialize(app)
      @app = app
    end

    def call(env)
      # 0. Skip for non-GET/HEAD requests to avoid interfering with form submissions (CSRF etc.)
      return @app.call(env) unless %w[GET HEAD].include?(env['REQUEST_METHOD'])

      # Also skip for admin routes as they don't involve legacy encodings
      return @app.call(env) if env['PATH_INFO']&.start_with?('/admin')

      fix_path(env)
      # クエリ文字列はルーティングに使われないため、PATH_INFOのように修復して保持する
      # 必要がない。不正なエンコードを含む場合は単に空にして無視する（issue #1374:
      # 文字化けしたクエリパラメータを含むリクエストが大量流入し、修復のための正規表現
      # 処理や、修復に失敗した場合のRailsの例外処理が応答時間を悪化させていた）。
      drop_invalid_query_string(env)

      @app.call(env)
    end

    private

    def fix_path(env)
      path = env['PATH_INFO']
      return unless path

      # 1. Handle Raw Bytes (Invalid UTF-8 in PATH_INFO itself)
      unless path.valid_encoding?
        path.force_encoding(Encoding::ASCII_8BIT)
        # Convert raw high-bit bytes to %25HH
        # We use %25 because we want Rails to decode it to "%HH" string, not raw byte.
        path = path.gsub(/[^[:ascii:]]/) do |match|
          "%25#{match.unpack1('H*').upcase}"
        end
        env['PATH_INFO'] = path
      end

      # 2. Handle Encoded EUC-JP (Valid ASCII PATH_INFO, but decodes to invalid UTF-8)
      # Check for percent-encoded high-bit bytes (0x80-0xFF)
      # These correspond to %80-%FF. Regex: %[89A-F][0-9A-F]
      return unless path.match?(/%[89a-fA-F][0-9a-fA-F]/)

      # Double-encode these specific sequences to preserve them as literal "%HH" strings
      # after Rails decoding.
      # e.g. "%B7" -> "%25B7" -> Rails decodes to "%B7"
      env['PATH_INFO'] = path.gsub(/%(?=[89a-fA-F][0-9a-fA-F])/, '%25')
    end

    def drop_invalid_query_string(env)
      query = env['QUERY_STRING']
      # blank?は内部で正規表現マッチを行い不正なエンコードの文字列に対して
      # ArgumentErrorを送出するため、ここではempty?で判定する
      return if query.nil? || query.empty?
      return if valid_query_string?(query)

      env['QUERY_STRING'] = ''
    end

    # 生のバイト列として不正なUTF-8を含む場合（PATH_INFOの1.と同様）はもちろん、
    # パーセントエンコードされたEUC-JP等が含まれる場合もデコード後にRailsで
    # InvalidParameterErrorになるため不正とみなす。全角英数字等の正規のUTF-8文字も
    # パーセントエンコードすると高位バイト（%80-%FF）になるため、PATH_INFOの2.のような
    # 「%HHが含まれるか」だけの判定では正規の検索クエリまで誤って弾いてしまう
    # （実際に全角英数字検索のテストが壊れた）。実際にデコードした上でUTF-8として
    # 妥当かどうかで判定する。
    #
    # 重要: RackはQUERY_STRINGを常にASCII-8BITとしてenvに渡す。ASCII-8BIT
    # （バイナリ）はどんなバイト列でも「妥当」と判定されてしまうため、
    # valid_encoding?をASCII-8BITのまま呼んでも常にtrueになり判定が機能しない
    # （本番相当のRack::MockRequestで再現し発覚）。実際に知りたいのは
    # 「UTF-8として妥当か」なので、force_encodingで明示的にUTF-8として
    # 解釈し直してから判定する。
    def valid_query_string?(query)
      utf8_query = query.dup.force_encoding(Encoding::UTF_8)
      return false unless utf8_query.valid_encoding?

      CGI.unescape(utf8_query).force_encoding(Encoding::UTF_8).valid_encoding?
    rescue ArgumentError
      false
    end
  end
end

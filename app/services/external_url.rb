# frozen_string_literal: true

# 外部サイトへ遷移させてよいURLかを検証し、正規化したURLを返す（issue #1823）。
# クッションページ（OutboundLinksController）の遷移先に使う。アイテム以外の外部リンクにも
# 使えるよう、モデルには依存させない。
#
# 許可するのは http / https の絶対URLのみ。次のものは nil を返す。
# - javascript: / data: などのスキーム、相対URL、プロトコル相対URL（//host）
# - ホストが無いもの
# - ユーザー情報付き（https://example.com@evil.example/ のようにドメインを偽装できる）
# - 空白・制御文字を含むもの（URLとして解釈される範囲がブラウザとずれるため）
# ASCII以外の文字はパーセントエンコードして返す。
module ExternalUrl
  module_function

  def sanitize(url)
    string = url.to_s
    return nil if string.empty? || string.match?(/[\s\p{Cc}]/)

    # 日本語のパス等はURI.parseが受け付けないため、ASCII以外の文字は先にパーセントエンコードする
    uri = URI.parse(string.gsub(/[^[:ascii:]]+/) { |chars| ERB::Util.url_encode(chars) })
    return nil unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  # 表示用のホスト名（先頭の www. は省く）。sanitize を通らないURLは nil
  def display_host(url)
    sanitized = sanitize(url)
    return nil unless sanitized

    URI.parse(sanitized).host.delete_prefix('www.')
  end
end

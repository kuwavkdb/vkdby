# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :logged_in?

  include Pagy::Method

  before_action :load_footer_page
  before_action :load_top_message_page

  private

  def load_footer_page
    @footer_page = CustomPage.published.find_by(key: 'footer')
  end

  def load_top_message_page
    @top_message_page = CustomPage.published.find_by(key: 'top_message')
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_login
    return if logged_in?

    store_return_to(request.fullpath) if request.get? || request.head?
    redirect_to login_path, alert: 'ログインしてください'
  end

  def store_return_to(path)
    safe_path = safe_return_to(path)
    session[:return_to] = safe_path if safe_path
  end

  RETURN_TO_MAX_LENGTH = 512

  # 外部から渡された値をそのまま使うとオープンリダイレクトの脆弱性になるため、
  # host/scheme を持たないサイト内の相対パスのみ許可する。
  # 単純な文字列プレフィックスチェック（"//"や"/\"始まりを弾くだけ）だと、
  # ブラウザがLocationヘッダー中のタブ/改行/復帰文字をどこにあっても除去してから
  # URLを解釈するため、"/\t/evil.com" のような値が "//evil.com" に変化して
  # プロトコル相対の外部リダイレクトを許してしまう。URI.parse で厳密に検証する。
  #
  # 長さも制限する。session はデフォルトで cookie に保存されるため、長すぎる
  # 値をそのまま入れると ActionDispatch::Cookies::CookieOverflow で 500 になる。
  def safe_return_to(path)
    return unless path.is_a?(String) && path.start_with?('/') && path.length <= RETURN_TO_MAX_LENGTH

    uri = URI.parse(path)
    path if uri.host.nil? && uri.scheme.nil?
  rescue URI::InvalidURIError
    nil
  end

  # 全角英数字（ＡＢＣ１２３など）で検索してもDB上の半角表記とマッチするよう、
  # 検索クエリをNFKCで正規化する（全角→半角、半角カナ→全角カナなど）。
  def normalize_search_query(query)
    query.to_s.unicode_normalize(:nfkc)
  end

  def valid_year?(year)
    year >= 1970 && year <= Date.today.year + 10
  end

  def render_not_found(query: nil)
    @not_found_query = decode_percent_encoded_key(query)
    render 'errors/not_found', status: :not_found
  end

  # Middleware::EucJpUrlFixer は旧EUC-JPリンク対策として、パス中の%XXを%25XXに
  # 再エンコードして保持するため、通常のUTF-8パーセントエンコードされたパス
  # （日本語キーなど）もRackの自動デコードを経ずに届く。404の検索欄プリフィル
  # 表示のためだけに、ここで改めてデコードを試みる。
  def decode_percent_encoded_key(key)
    return key if key.blank?

    decoded = URI::DEFAULT_PARSER.unescape(key)
    decoded.valid_encoding? ? decoded : key
  end
end

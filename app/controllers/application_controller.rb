# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :logged_in?

  include Pagy::Method

  before_action :redirect_to_canonical_domain
  before_action :load_footer_page

  private

  def redirect_to_canonical_domain
    return unless request.host == 'vkdby.onrender.com'

    redirect_to request.url.sub('vkdby.onrender.com', 'next.vkdb.jp'), status: :moved_permanently, allow_other_host: true
  end

  def load_footer_page
    @footer_page = CustomPage.published.find_by(key: 'footer')
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_login
    return if logged_in?

    redirect_to login_path, alert: 'ログインしてください'
  end

  def valid_year?(year)
    year >= 1970 && year <= Date.today.year + 10
  end

  def render_not_found
    render file: Rails.root.join('public/404.html'), status: :not_found, layout: false
  end
end

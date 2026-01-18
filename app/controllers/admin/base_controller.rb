class Admin::BaseController < ApplicationController
  before_action :require_login
  # layout 'admin' # Use default implementation for now until layout is created

  private

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "権限がありません"
    end
  end

  def require_super_operator
    unless current_user&.super_operator_or_above?
      redirect_to admin_root_path, alert: "権限がありません"
    end
  end
end

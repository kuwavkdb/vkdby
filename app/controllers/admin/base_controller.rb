# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :require_login
    # layout 'admin' # Use default implementation for now until layout is created

    private

    def require_admin
      return if current_user&.admin?

      redirect_to root_path, alert: '権限がありません'
    end

    def require_super_operator
      return if current_user&.super_operator_or_above?

      redirect_to admin_root_path, alert: '権限がありません'
    end
  end
end

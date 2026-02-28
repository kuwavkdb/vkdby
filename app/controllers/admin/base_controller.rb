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

    def record_update_log(record, action:)
      diff = case action
             when 'create'
               record.saved_changes.except('created_at', 'updated_at')
             when 'update'
               record.saved_changes.except('updated_at')
             end

      UpdateLog.create!(
        user: current_user,
        action: action,
        loggable: record,
        diff: diff
      )
    end
  end
end

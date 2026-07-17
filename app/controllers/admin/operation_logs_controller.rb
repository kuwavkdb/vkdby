# frozen_string_literal: true

module Admin
  class OperationLogsController < Admin::BaseController
    before_action :require_admin

    def index
      @pagy, @operation_logs = pagy(OperationLog.includes(:user).order(created_at: :desc), limit: 50)
    end
  end
end

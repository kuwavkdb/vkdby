# frozen_string_literal: true

module Admin
  class UnitSubmissionsController < Admin::BaseController
    before_action :require_admin

    STATUS_FILTERS = %w[pending rejected converted].freeze

    def index
      @status_filter = STATUS_FILTERS.include?(params[:status]) ? params[:status] : 'pending'
      scope = UnitSubmission.public_send(@status_filter).includes(:links, :converted_unit)
      @pagy, @unit_submissions = pagy(scope.order(created_at: :desc))
    end

    def reject
      unit_submission = UnitSubmission.pending.find(params[:id])
      unit_submission.update!(submission_status: :rejected)
      redirect_to admin_unit_submissions_path, notice: '投稿を却下しました'
    end
  end
end

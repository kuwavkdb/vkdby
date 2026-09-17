# frozen_string_literal: true

module Admin
  class TrendSubmissionsController < Admin::BaseController
    before_action :require_admin

    STATUS_FILTERS = %w[pending rejected converted].freeze

    def index
      @status_filter = STATUS_FILTERS.include?(params[:status]) ? params[:status] : 'pending'
      scope = TrendSubmission.public_send(@status_filter).includes(:converted_trend)
      @pagy, @trend_submissions = pagy(scope.order(created_at: :desc))
    end

    def reject
      trend_submission = TrendSubmission.pending.find(params[:id])
      trend_submission.update!(submission_status: :rejected)
      redirect_to admin_trend_submissions_path, notice: '投稿を却下しました'
    end
  end
end

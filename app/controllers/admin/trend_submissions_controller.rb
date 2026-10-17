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

    # すでにある動向に手で反映した・別の経路で登録済みだったなど、動向を新しく作らずに処理を終える（issue #1902）。
    # 状態は「変換済み」にまとめ、converted_trend は空のままにする
    def resolve
      trend_submission = TrendSubmission.pending.find(params[:id])
      trend_submission.update!(submission_status: :converted)
      redirect_to admin_trend_submissions_path, notice: '投稿を対応済みにしました'
    end
  end
end

# frozen_string_literal: true

module Admin
  # ユニット・個人の情報の訂正の投稿（issue #1902）の確認・却下・対応済みにする。ほかの投稿と同じく admin のみ。
  # 対象を編集して反映したあと「対応済みにする」（resolve）で resolved にする
  class ProfileCorrectionsController < Admin::BaseController
    before_action :require_admin

    STATUS_FILTERS = ProfileCorrection.submission_statuses.keys.freeze
    TARGET_FILTERS = ProfileCorrection::TARGET_TYPES

    def index
      @status_filter = STATUS_FILTERS.include?(params[:status]) ? params[:status] : 'pending'
      @target_filter = params[:target_type].presence_in(TARGET_FILTERS)
      scope = ProfileCorrection.public_send(@status_filter).includes(:target)
      scope = scope.where(target_type: @target_filter) if @target_filter
      @pagy, @profile_corrections = pagy(scope.recent)
    end

    def reject
      profile_correction = ProfileCorrection.pending.find(params[:id])
      profile_correction.update!(submission_status: :rejected)
      redirect_back_or_to admin_profile_corrections_path, notice: '訂正の投稿を却下しました'
    end

    def resolve
      profile_correction = ProfileCorrection.pending.find(params[:id])
      profile_correction.update!(submission_status: :resolved)
      redirect_back_or_to admin_profile_corrections_path, notice: '訂正の投稿を対応済みにしました'
    end
  end
end

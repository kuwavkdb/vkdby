# frozen_string_literal: true

module Admin
  # 会場の投稿（issue #1814）の確認・却下・対応済みにする。ユニット・動向の投稿と同じく admin のみ。
  # 新しい会場の投稿は「登録する」から会場の新規作成画面（venue_submission_id を引き継ぐ）で会場を作ると converted になる。
  # 訂正の投稿は会場を編集して反映したあと「対応済みにする」（resolve）で converted にする
  class VenueSubmissionsController < Admin::BaseController
    before_action :require_admin

    STATUS_FILTERS = %w[pending rejected converted].freeze
    KIND_FILTERS = VenueSubmission.submission_kinds.keys.freeze

    def index
      @status_filter = STATUS_FILTERS.include?(params[:status]) ? params[:status] : 'pending'
      @kind_filter = params[:kind].presence_in(KIND_FILTERS)
      scope = VenueSubmission.public_send(@status_filter).includes(:venue, :converted_venue)
      scope = scope.where(submission_kind: @kind_filter) if @kind_filter
      @pagy, @venue_submissions = pagy(scope.recent)
    end

    def reject
      venue_submission = VenueSubmission.pending.find(params[:id])
      venue_submission.update!(submission_status: :rejected)
      redirect_back_or_to admin_venue_submissions_path, notice: '投稿を却下しました'
    end

    def resolve
      venue_submission = VenueSubmission.pending.correction.find(params[:id])
      venue_submission.update!(submission_status: :converted, converted_venue: venue_submission.venue)
      redirect_back_or_to admin_venue_submissions_path, notice: '訂正の投稿を対応済みにしました'
    end
  end
end

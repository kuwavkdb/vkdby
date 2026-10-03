# frozen_string_literal: true

module Admin
  class UnitSubmissionsController < Admin::BaseController
    before_action :require_admin

    STATUS_FILTERS = %w[pending rejected converted].freeze

    def index
      @status_filter = STATUS_FILTERS.include?(params[:status]) ? params[:status] : 'pending'
      scope = UnitSubmission.public_send(@status_filter).includes(:links, :converted_unit, images_attachments: :blob)
      @pagy, @unit_submissions = pagy(scope.order(created_at: :desc))
    end

    def reject
      unit_submission = UnitSubmission.pending.find(params[:id])
      unit_submission.update!(submission_status: :rejected)
      # 却下した投稿の画像はサイトで使わないため、R2から削除する（issue #1718）
      unit_submission.images.purge_later
      redirect_to admin_unit_submissions_path, notice: '投稿を却下しました'
    end

    # 変換済みの投稿に残っている（縮小済みの）画像を、変換先Unitの「画像」セクションへ移す（issue #1719）
    def add_image_to_unit
      unit_submission = UnitSubmission.converted.find(params[:id])
      unit = unit_submission.converted_unit
      if unit.nil? || unit.discarded? || !UnitSubmissionImageTransfer.usable?(unit_submission)
        return redirect_to admin_unit_submissions_path(status: 'converted'), alert: 'この画像はUnitに追加できません'
      end

      section = UnitSubmissionImageTransfer.new(unit_submission, unit).move([params[:attachment_id]])
      return redirect_to admin_unit_submissions_path(status: 'converted'), alert: '画像が見つかりませんでした' unless section

      record_update_log(section, action: section.previously_new_record? ? 'create' : 'update', subject: unit)
      redirect_to admin_unit_submissions_path(status: 'converted'),
                  notice: "画像を「#{unit.name}」の「#{section.name}」セクションに追加しました"
    end
  end
end

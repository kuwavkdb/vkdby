# frozen_string_literal: true

class TrendSubmissionsController < ApplicationController
  def new
    @trend_submission = TrendSubmission.new(target_params)
  end

  def create
    @trend_submission = TrendSubmission.new(trend_submission_params)
    @trend_submission.submitter_ip = request.remote_ip

    if @trend_submission.save
      notify_admins(@trend_submission)
      redirect_to new_trend_submission_path(redirect_target_params),
                  notice: '投稿ありがとうございました。内容を確認のうえ、掲載を検討させていただきます。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Unit/Person詳細ページからの導線では対象を固定するためtarget_type/target_id/target_nameを
  # hidden_fieldで渡す（issue #1553）。汎用エントリーポイントではこれらのパラメータは渡されず、
  # 投稿者自身が対象種別・対象名を入力する
  def target_params
    params.permit(:target_type, :target_id, :target_name)
  end

  def redirect_target_params
    return {} if @trend_submission.target_id.blank?

    { target_type: @trend_submission.target_type, target_id: @trend_submission.target_id,
      target_name: @trend_submission.target_name }
  end

  def trend_submission_params
    params.require(:trend_submission).permit(
      :target_type, :target_id, :target_name,
      :date, :day_unknown, :month_unknown,
      :title, :content, :via_url,
      :phenomenon, :email, :is_related_person
    )
  end

  def notify_admins(trend_submission)
    User.admin.find_each do |admin_user|
      UserMailer.new_trend_submission_email(trend_submission, admin_user).deliver_later
    end
  end
end

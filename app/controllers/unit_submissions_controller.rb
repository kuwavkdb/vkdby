# frozen_string_literal: true

class UnitSubmissionsController < ApplicationController
  LINK_FIELD_COUNT = 3

  def new
    @unit_submission = UnitSubmission.new
    build_blank_links(@unit_submission)
  end

  def create
    @unit_submission = UnitSubmission.new(unit_submission_params)
    @unit_submission.submitter_ip = request.remote_ip

    if @unit_submission.save
      notify_admins(@unit_submission)
      redirect_to new_unit_submission_path, notice: '投稿ありがとうございました。内容を確認のうえ、掲載を検討させていただきます。'
    else
      build_blank_links(@unit_submission) if @unit_submission.links.none?(&:new_record?)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def build_blank_links(unit_submission)
    LINK_FIELD_COUNT.times { unit_submission.links.build }
  end

  def unit_submission_params
    params.require(:unit_submission).permit(
      :name, :name_kana, :unit_type, :status, :note, :email, :is_related_person,
      links_attributes: %i[url]
    )
  end

  def notify_admins(unit_submission)
    User.admin.find_each do |admin_user|
      UserMailer.new_unit_submission_email(unit_submission, admin_user).deliver_later
    end
  end
end

# frozen_string_literal: true

# ログイン不要の、既存のユニット・個人の情報の訂正の投稿フォーム（issue #1902）。
# /profile_corrections/new?key=... で対象を固定する。会場の訂正（VenueSubmissionsController）と同じ作り
class ProfileCorrectionsController < ApplicationController
  PERMITTED_ATTRIBUTES = %i[correction source_url note email].freeze

  before_action :set_profile_correction

  def new; end

  def create
    @profile_correction.assign_attributes(profile_correction_params)
    @profile_correction.submitter_ip = request.remote_ip

    if @profile_correction.save
      notify_admins(@profile_correction)
      redirect_to profile_path(@profile_correction.target.key),
                  notice: '投稿ありがとうございました。内容を確認のうえ、反映を検討させていただきます。'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  # 訂正の対象にできないユニット・個人（論理削除済み・仮登録など）は404
  def set_profile_correction
    target = ProfileCorrection.correctable_target(params[:key])
    raise ActiveRecord::RecordNotFound unless target

    @profile_correction = ProfileCorrection.new(target: target)
  end

  def profile_correction_params
    submitted = params[:profile_correction]
    # ログイン不要のフォームなので、ハッシュ以外が送られても500にしない
    submitted.is_a?(ActionController::Parameters) ? submitted.permit(*PERMITTED_ATTRIBUTES) : {}
  end

  def notify_admins(profile_correction)
    User.admin.find_each do |admin_user|
      UserMailer.new_profile_correction_email(profile_correction, admin_user).deliver_later
    end
  end
end

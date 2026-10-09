# frozen_string_literal: true

# ログイン不要の会場の投稿フォーム（issue #1814）。
# /venue_submissions/new は新しい会場、/venue_submissions/new?venue_id=... はその会場の訂正の投稿。
# 新しい会場は、名前・別名・旧名が一致しそうな会場がすでにあれば候補を見せて確認してもらう（投稿自体は止めない）
class VenueSubmissionsController < ApplicationController
  NEW_VENUE_ATTRIBUTES = %i[name name_kana venue_type prefecture area address capacity].freeze
  COMMON_ATTRIBUTES = %i[source_url note email].freeze

  def new
    @venue_submission = build_submission
    @area_options = Venue.area_options if @venue_submission.new_venue?
  end

  def create
    @venue_submission = build_submission
    @venue_submission.assign_attributes(submission_params)
    @venue_submission.submitter_ip = request.remote_ip

    if @venue_submission.valid? && duplicate_candidates_confirmed?
      @venue_submission.save!
      notify_admins(@venue_submission)
      redirect_to after_submit_path, notice: '投稿ありがとうございました。内容を確認のうえ、掲載を検討させていただきます。'
    else
      @area_options = Venue.area_options if @venue_submission.new_venue?
      render :new, status: :unprocessable_entity
    end
  end

  private

  # venue_id があれば訂正、なければ新しい会場の投稿。訂正の対象にできない会場（論理削除済みなど）は404
  def build_submission
    return VenueSubmission.new(submission_kind: :new_venue) if params[:venue_id].blank?

    venue = VenueSubmission.correctable_venue(params[:venue_id])
    raise ActiveRecord::RecordNotFound unless venue

    VenueSubmission.new(submission_kind: :correction, venue: venue)
  end

  def submission_params
    attributes = @venue_submission.correction? ? [:correction, *COMMON_ATTRIBUTES] : [*NEW_VENUE_ATTRIBUTES, *COMMON_ATTRIBUTES]
    params.fetch(:venue_submission, {}).permit(*attributes)
  end

  # 新しい会場の投稿で、似た会場があるのにまだ確認していなければ、候補を表示してもう一度送ってもらう
  def duplicate_candidates_confirmed?
    return true if @venue_submission.correction? || params[:confirmed].present?

    @similar_venues = Venue.kept.where(destination_key: nil)
                           .matching(normalize_search_query(@venue_submission.name)).order(:name).limit(10).to_a
    @similar_venues.empty?
  end

  def after_submit_path
    @venue_submission.correction? ? venue_path(@venue_submission.venue.key) : new_venue_submission_path
  end

  def notify_admins(venue_submission)
    User.admin.find_each do |admin_user|
      UserMailer.new_venue_submission_email(venue_submission, admin_user).deliver_later
    end
  end
end

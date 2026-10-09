# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def welcome_email(user, temp_password)
    @user = user
    @temp_password = temp_password
    @url = login_url
    mail(to: @user.email, subject: 'Welcome to VKDBY - Your Account Credentials')
  end

  def new_unit_submission_email(unit_submission, admin_user)
    @unit_submission = unit_submission
    @admin_user = admin_user
    @url = admin_unit_submissions_url
    mail(to: @admin_user.email, subject: "[VKDBY] 新しいユニット投稿があります: #{@unit_submission.name}")
  end

  def new_trend_submission_email(trend_submission, admin_user)
    @trend_submission = trend_submission
    @admin_user = admin_user
    @url = admin_trend_submissions_url
    mail(to: @admin_user.email, subject: "[VKDBY] 新しい動向投稿があります: #{@trend_submission.target_name}")
  end

  # 会場の投稿（issue #1814）。新しい会場と既存の会場の訂正で件名を分ける
  def new_venue_submission_email(venue_submission, admin_user)
    @venue_submission = venue_submission
    @admin_user = admin_user
    @url = admin_venue_submissions_url(kind: venue_submission.submission_kind)
    subject = if venue_submission.correction?
                "[VKDBY] 会場の訂正の投稿があります: #{venue_submission.display_name}"
              else
                "[VKDBY] 新しい会場の投稿があります: #{venue_submission.display_name}"
              end
    mail(to: @admin_user.email, subject: subject)
  end
end

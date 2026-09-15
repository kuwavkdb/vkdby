# frozen_string_literal: true

class UserMailer < ApplicationMailer
  default from: 'notifications@example.com'

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
end

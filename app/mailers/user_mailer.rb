# frozen_string_literal: true

class UserMailer < ApplicationMailer
  default from: 'notifications@example.com'

  def welcome_email(user, temp_password)
    @user = user
    @temp_password = temp_password
    @url = login_url
    mail(to: @user.email, subject: 'Welcome to VKDBY - Your Account Credentials')
  end
end

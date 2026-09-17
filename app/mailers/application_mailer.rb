# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  # Gmail SMTP (issue #1560) requires the From header to match the authenticated
  # account, so this is sourced from the same credential as smtp_settings.user_name
  # rather than a fixed address.
  default from: Rails.application.credentials.dig(:smtp, :user_name) || 'from@example.com'
  layout 'mailer'
end

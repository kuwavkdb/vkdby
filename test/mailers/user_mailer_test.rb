require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "welcome_email" do
    user = users(:one)
    mail = UserMailer.welcome_email(user, "password123")
    assert_equal "Welcome to VKDBY - Your Account Credentials", mail.subject
    assert_equal [ user.email ], mail.to
    assert_equal [ "notifications@example.com" ], mail.from
    assert_match "Welcome back to VKDBY", mail.body.encoded
  end
end

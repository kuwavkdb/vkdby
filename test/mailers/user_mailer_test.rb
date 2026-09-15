# frozen_string_literal: true

require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  test 'welcome_email' do
    user = users(:one)
    mail = UserMailer.welcome_email(user, 'password123')
    assert_equal 'Welcome to VKDBY - Your Account Credentials', mail.subject
    assert_equal [user.email], mail.to
    assert_equal ['notifications@example.com'], mail.from
    assert_match 'Welcome back to VKDBY', mail.body.encoded
  end

  test 'new_unit_submission_email' do
    admin_user = users(:admin)
    unit_submission = UnitSubmission.create!(name: 'Submitted Unit', links_attributes: { '0' => { url: 'https://example.com' } })

    mail = UserMailer.new_unit_submission_email(unit_submission, admin_user)

    assert_equal '[VKDBY] 新しいユニット投稿があります: Submitted Unit', mail.subject
    assert_equal [admin_user.email], mail.to
    assert_equal ['notifications@example.com'], mail.from
    assert_match 'Submitted Unit', mail.text_part.decoded
  end
end

# frozen_string_literal: true

require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  test 'welcome_email' do
    user = users(:one)
    mail = UserMailer.welcome_email(user, 'password123')
    assert_equal 'Welcome to VKDBY - Your Account Credentials', mail.subject
    assert_equal [user.email], mail.to
    assert_equal ['from@example.com'], mail.from
    assert_match 'Welcome back to VKDBY', mail.body.encoded
  end

  test 'new_unit_submission_email' do
    admin_user = users(:admin)
    unit_submission = UnitSubmission.create!(name: 'Submitted Unit', unit_type: 'band', status: 'active',
                                             links_attributes: { '0' => { url: 'https://example.com' } })

    mail = UserMailer.new_unit_submission_email(unit_submission, admin_user)

    assert_equal '[VKDBY] 新しいユニット投稿があります: Submitted Unit', mail.subject
    assert_equal [admin_user.email], mail.to
    assert_equal ['from@example.com'], mail.from
    assert_match 'Submitted Unit', mail.text_part.decoded
  end

  test 'new_trend_submission_email' do
    admin_user = users(:admin)
    trend_submission = TrendSubmission.create!(target_type: :unit, target_name: 'Submitted Unit',
                                               date: Date.new(2026, 1, 1), via_url: 'https://example.com',
                                               phenomenon: Trend.unit_phenomenons['announcement'])

    mail = UserMailer.new_trend_submission_email(trend_submission, admin_user)

    assert_equal '[VKDBY] 新しい動向投稿があります: Submitted Unit', mail.subject
    assert_equal [admin_user.email], mail.to
    assert_equal ['from@example.com'], mail.from
    assert_match 'Submitted Unit', mail.text_part.decoded
  end

  test 'on_this_day_post_email（issue #1742）' do
    admin_user = users(:admin)
    result = OnThisDayPost.new(date: Date.new(2026, 5, 30),
                               text: "ヴィジュアル系今日はなんの日？\n・1995年 黒夢 解散\n#vkdb",
                               page_url: 'https://example.com/date/-/5/30')

    mail = UserMailer.on_this_day_post_email(admin_user, result)

    assert_equal '[VKDBY] 5月30日の「今日はなんの日？」投稿文', mail.subject
    assert_equal [admin_user.email], mail.to
    text = mail.text_part.decoded
    assert_includes text, '・1995年 黒夢 解散'
    assert_includes text, result.intent_url
    assert_includes text, "文字数（X換算）: #{result.weighted_length} / 280"
    assert_includes mail.html_part.decoded, 'X の投稿画面を開く'
  end

  test 'on_this_day_no_content_email（issue #1742）' do
    admin_user = users(:admin)

    mail = UserMailer.on_this_day_no_content_email(admin_user, Date.new(2026, 5, 31), 'https://example.com/date/-/5/31')

    assert_equal '[VKDBY] 5月31日の「今日はなんの日？」投稿文はありません', mail.subject
    assert_equal [admin_user.email], mail.to
    assert_includes mail.text_part.decoded, 'https://example.com/date/-/5/31'
  end
end

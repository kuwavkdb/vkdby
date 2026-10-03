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

  # 「今日はなんの日？」の紹介ポスト文（issue #1742）。result は OnThisDayPost
  def on_this_day_post_email(admin_user, result)
    @admin_user = admin_user
    @result = result
    mail(to: @admin_user.email,
         subject: "[VKDBY] #{result.date.month}月#{result.date.day}日の「今日はなんの日？」投稿文")
  end

  # 「今日はなんの日？」の投稿文を作る内容（動向・誕生日）がなかった日の通知（issue #1742）
  def on_this_day_no_content_email(admin_user, date, page_url)
    @admin_user = admin_user
    @date = date
    @page_url = page_url
    mail(to: @admin_user.email, subject: "[VKDBY] #{date.month}月#{date.day}日の「今日はなんの日？」投稿文はありません")
  end
end

# frozen_string_literal: true

# 指定日の「今日はなんの日？」投稿文（OnThisDayPostBuilder）を admin ユーザー全員にメールする（issue #1742）。
# 動向も誕生日もない日は、送る内容がない旨をメールする。
# 送信記録は残さない（GitHub Actions のcronから1日1回呼ぶだけで、再実行で複数回届いても問題ないため）。
# 戻り値: :sent / :no_content（送る内容がない旨を送った）/ :no_recipients（admin がいない）
class OnThisDayMailSender
  def initialize(date)
    @date = date
  end

  def call
    admins = User.admin.to_a
    return :no_recipients if admins.empty?

    builder = OnThisDayPostBuilder.new(@date)
    result = builder.build
    admins.each do |admin|
      mail = if result
               UserMailer.on_this_day_post_email(admin, result)
             else
               UserMailer.on_this_day_no_content_email(admin, @date, builder.page_url)
             end
      mail.deliver_now
    end
    result ? :sent : :no_content
  end
end

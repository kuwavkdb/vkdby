# frozen_string_literal: true

# 指定日の「今日はなんの日？」投稿文（OnThisDayPostBuilder）を admin ユーザー全員にメールする（issue #1742）。
# 同じ日に二度送らないよう OnThisDayMailDelivery に記録する。メール送信に失敗した場合は記録ごと
# ロールバックし、再実行で送り直せるようにする。
# 戻り値: :sent / :already_sent / :skipped（動向も誕生日もない日）/ :no_recipients（admin がいない）
class OnThisDayMailSender
  def initialize(date)
    @date = date
  end

  def call
    return :already_sent if OnThisDayMailDelivery.exists?(date: @date)

    result = OnThisDayPostBuilder.new(@date).build
    return :skipped unless result

    admins = User.admin.to_a
    return :no_recipients if admins.empty?

    OnThisDayMailDelivery.transaction do
      OnThisDayMailDelivery.create!(date: @date, body: result.text)
      admins.each { |admin| UserMailer.on_this_day_post_email(admin, result).deliver_now }
    end
    :sent
  rescue ActiveRecord::RecordNotUnique
    :already_sent
  end
end

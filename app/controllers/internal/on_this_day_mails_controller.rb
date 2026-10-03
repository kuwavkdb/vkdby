# frozen_string_literal: true

module Internal
  # 「今日はなんの日？」投稿文を管理者へメールする（issue #1742）。
  # GitHub Actions（.github/workflows/on_this_day_mail.yml）から毎日 JST 0:00 に呼ぶ。
  # ブラウザ向けの ApplicationController は allow_browser でcurl等を弾くため、ActionController::API を使う。
  # 認証は環境変数 ON_THIS_DAY_MAIL_TOKEN との Bearer トークン照合で、未設定ならエンドポイントごと無効（404）
  class OnThisDayMailsController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods

    TOKEN_ENV = 'ON_THIS_DAY_MAIL_TOKEN'

    before_action :authenticate

    def create
      date = target_date
      return render json: { error: 'invalid date' }, status: :unprocessable_entity unless date

      status = OnThisDayMailSender.new(date).call
      render json: { status: status, date: date.strftime('%m-%d') }
    end

    private

    def authenticate
      expected = ENV.fetch(TOKEN_ENV, '')
      return head :not_found if expected.blank?

      authenticate_or_request_with_http_token do |token, _options|
        ActiveSupport::SecurityUtils.secure_compare(token, expected)
      end
    end

    # 既定は JST の当日。手動実行で別の日を送る場合などに date=MM-DD で指定できる（年は使わない）
    def target_date
      return OnThisDayPostBuilder.today if params[:date].blank?

      OnThisDayPostBuilder.parse_month_day(params[:date])
    end
  end
end

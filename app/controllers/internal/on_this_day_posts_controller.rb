# frozen_string_literal: true

module Internal
  # 「今日は何の日？」投稿文をJSONで返す（issue #1742）。
  # GitHub Actions（.github/workflows/on_this_day.yml）から毎日 JST 0:00 に呼び、結果を GitHub の Issue にコメントする。
  # ブラウザ向けの ApplicationController は allow_browser でcurl等を弾くため、ActionController::API を使う。
  # 認証は環境変数 ON_THIS_DAY_MAIL_TOKEN との Bearer トークン照合で、未設定ならエンドポイントごと無効（404）。
  # 環境変数名はメール送信時代のもの（Render と GitHub Secrets の設定をそのまま使うため据え置き）
  class OnThisDayPostsController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods

    TOKEN_ENV = 'ON_THIS_DAY_MAIL_TOKEN'

    before_action :authenticate

    # status は ok（投稿文あり）/ no_content（動向も誕生日もなく投稿文を作らなかった）。
    # posts は出来事（kind: trends）・誕生日（kind: birthdays）の順で、内容がない方は含めない（issue #1753）
    def show
      date = target_date
      return render json: { error: 'invalid date' }, status: :unprocessable_entity unless date

      builder = OnThisDayPostBuilder.new(date)
      posts = builder.build
      render json: { status: posts.any? ? 'ok' : 'no_content', date: date.strftime('%m-%d'),
                     page_url: builder.page_url, posts: posts.map { |post| post_json(post) } }
    end

    private

    def post_json(post)
      { kind: post.kind, text: post.text, weighted_length: post.weighted_length, max_length: XPostLength::MAX,
        intent_url: post.intent_url }
    end

    def authenticate
      expected = ENV.fetch(TOKEN_ENV, '')
      return head :not_found if expected.blank?

      authenticate_or_request_with_http_token do |token, _options|
        ActiveSupport::SecurityUtils.secure_compare(token, expected)
      end
    end

    # 既定は JST の当日。手動実行で別の日を出す場合などに date=MM-DD で指定できる（年は使わない）
    def target_date
      return OnThisDayPostBuilder.today if params[:date].blank?

      OnThisDayPostBuilder.parse_month_day(params[:date])
    end
  end
end

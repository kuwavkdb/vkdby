# frozen_string_literal: true

require 'test_helper'

# issue #1374 の修正後もEUC-JPで壊れたQUERY_STRINGを含むリクエストで
# ActionController::BadRequest (Invalid encoding for parameter) が発生する
# 事象を、実際のミドルウェアスタック全体（EucJpUrlFixer単体ではなく）を通して
# 再現・調査するためのテスト。
class EucJpQueryStringTest < ActionDispatch::IntegrationTest
  test 'wiki.cgiへの文字化けクエリを含むリクエストが例外を起こさない' do
    # 実際にログで観測された、EUC-JPで「発売スケジュール」をパーセントエンコードした
    # クエリを含むリクエスト。/wiki.cgi は現行ルーティングでは catch-all の
    # get '/:key' => profiles#show にマッチし、そのままprofileが見つからず
    # 404相当になること自体は許容するが、例外が発生しないことを確認する。
    get '/wiki.cgi?page=%C8%AF%C7%E4%A5%B9%A5%B1%A5%B8%A5%E5%A1%BC%A5%EB&nocache=1'

    assert_response :not_found
  end
end

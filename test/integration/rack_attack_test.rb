# frozen_string_literal: true

require 'test_helper'

# config/initializers/rack_attack.rb の people_units_filter 関連ルールを、
# 実際のミドルウェアスタック全体を通して検証する（issue #1439, #1478）。
class RackAttackTest < ActionDispatch::IntegrationTest
  test 'tag_idsを4カテゴリ以上指定したpeople検索は即座にブロックされる' do
    get '/people', params: { tag_ids: { '1' => '1', '2' => '2', '3' => '3', '4' => '4' } }

    assert_response :forbidden
  end

  test 'tag_idsを4カテゴリ以上指定したunits検索は即座にブロックされる' do
    get '/units', params: { tag_ids: { '1' => '1', '2' => '2', '3' => '3', '4' => '4' } }

    assert_response :forbidden
  end

  test 'tag_idsが3カテゴリまでのunits検索はブロックされない（現状UIの最大値）' do
    get '/units', params: { tag_ids: { '1' => '1', '2' => '2', '3' => '3' } }

    assert_response :success
  end

  test 'tag_idsが1カテゴリのpeople検索はブロックされない（現状UIの最大値）' do
    get '/people', params: { tag_ids: { '1' => '1' } }

    assert_response :success
  end
end

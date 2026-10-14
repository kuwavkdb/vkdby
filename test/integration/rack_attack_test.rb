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

  test '既知のボットUAによるGET /loginは即座にブロックされる（issue #1492）' do
    get '/login', headers: { 'User-Agent' => 'Mozilla/5.0 AppleWebKit/537.36 (compatible; Amazonbot/0.1; +https://developer.amazon.com/support/amazonbot)' }

    assert_response :forbidden
  end

  test '通常のUAによるGET /loginはブロックされない' do
    ua = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_7_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.6943.141 Safari/537.36'
    get '/login', headers: { 'User-Agent' => ua }

    assert_response :success
  end

  # 以下は回数制限（throttle）の検証。テスト環境のキャッシュは null_store でカウントされないため、
  # テストごとに MemoryStore へ差し替える
  test '絞り込み条件を3種類以上重ねたpeople検索は、IPごとに1分5回を超えると429になる（issue #1863）' do
    with_rack_attack_memory_store do
      params = { blood: 'A', hometown: '東京都', status: 'active' }
      5.times do
        get '/people', params: params
        assert_response :success
      end

      get '/people', params: params
      assert_response :too_many_requests
    end
  end

  test '絞り込み条件が2種類までのpeople検索は回数制限されない（issue #1863）' do
    with_rack_attack_memory_store do
      6.times do
        get '/people', params: { blood: 'A', hometown: '東京都' }
        assert_response :success
      end
    end
  end

  test '制限・ブロックしたリクエストは規則の名前・パス・User-Agent・IPをログに出す（issue #1863）' do
    output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)

    get '/people', params: { tag_ids: { '1' => '1', '2' => '2', '3' => '3', '4' => '4' } },
                   headers: { 'User-Agent' => 'TestCrawler/1.0' }

    assert_response :forbidden
    assert_match %r{\[Rack::Attack\] blocklist rule=block_excessive_tag_combo/people_units_filter ip=127\.0\.0\.1 path=/people\?}, output.string
    assert_match 'ua="TestCrawler/1.0"', output.string
  ensure
    Rails.logger = original_logger
  end

  private

  def with_rack_attack_memory_store
    original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rack::Attack.cache.store = original_store
  end
end

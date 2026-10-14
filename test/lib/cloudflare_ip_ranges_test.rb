# frozen_string_literal: true

require 'test_helper'

# issue #1867: Cloudflare の IP を信頼するプロキシとして扱い、X-Forwarded-For から利用者の IP を取り出す
class CloudflareIpRangesTest < ActiveSupport::TestCase
  CLIENT_IP = '97.165.122.172'
  CLOUDFLARE_IP = '104.22.66.6'

  def env_for(forwarded_for, remote_addr: '10.0.0.1')
    Rack::MockRequest.env_for('/', 'REMOTE_ADDR' => remote_addr, 'HTTP_X_FORWARDED_FOR' => forwarded_for)
  end

  def rails_remote_ip(env)
    remote_ip = nil
    app = ->(e) { remote_ip = ActionDispatch::Request.new(e).remote_ip and [200, {}, []] }
    ActionDispatch::RemoteIp.new(app, false, Rails.application.config.action_dispatch.trusted_proxies).call(env)
    remote_ip
  end

  test 'Cloudflareの範囲のIPを判定できる（IPv4・IPv6）' do
    %w[104.22.66.6 172.71.124.193 162.158.163.201 2606:4700::1].each do |ip|
      assert CloudflareIpRanges.include?(ip), ip
    end
    %w[97.165.122.172 17.166.20.88 8.8.8.8 2001:db8::1].each do |ip|
      assert_not CloudflareIpRanges.include?(ip), ip
    end
  end

  test 'IPとして読めない値はCloudflareとみなさない' do
    assert_not CloudflareIpRanges.include?('unknown')
    assert_not CloudflareIpRanges.include?(nil)
  end

  test 'Cloudflare経由のリクエストでは、Rack::Request#ipが利用者のIPを返す' do
    request = Rack::Request.new(env_for("#{CLIENT_IP}, #{CLOUDFLARE_IP}"))

    assert_equal CLIENT_IP, request.ip
  end

  test 'Cloudflare経由のリクエストでは、request.remote_ipが利用者のIPを返す' do
    assert_equal CLIENT_IP, rails_remote_ip(env_for("#{CLIENT_IP}, #{CLOUDFLARE_IP}"))
  end

  test 'Cloudflare以外のIPは飛ばさない（X-Forwarded-Forを偽装されても信頼する範囲は広がらない）' do
    env = env_for("#{CLOUDFLARE_IP}, 8.8.8.8")

    assert_equal '8.8.8.8', Rack::Request.new(env).ip
    assert_equal '8.8.8.8', rails_remote_ip(env)
  end
end

# frozen_string_literal: true

# Rack::Request#ip が、X-Forwarded-For の Cloudflare の IP を飛ばして利用者の IP を返すようにする（issue #1867）。
# Rack::Attack の IP ごとの制限と Middleware::IpBlocker がこの値を使う。
# Rack の既定（ローカル・プライベート IP を信頼する）はそのまま残し、Cloudflare の範囲を加える。
# request.remote_ip（Rails）側は config/application.rb の trusted_proxies で設定している。
default_ip_filter = Rack::Request.ip_filter
Rack::Request.ip_filter = lambda do |ip|
  default_ip_filter.call(ip) || CloudflareIpRanges.include?(ip)
end

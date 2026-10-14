# frozen_string_literal: true

require 'ipaddr'

# Cloudflare が利用者からのリクエストを中継するときに使う IP の範囲（issue #1867）。
# 本番は 利用者 → Cloudflare → Render → アプリ の順に届き、X-Forwarded-For は「利用者の IP, Cloudflare の IP」になる。
# Rack・Rails が既定で信頼するプロキシはプライベート IP だけのため、Cloudflare の IP を利用者の IP として扱い、
# Rack::Attack の IP ごとの制限を、同じ Cloudflare の拠点を通る利用者全員で共有していた。
# この範囲を信頼するプロキシに加え、X-Forwarded-For から利用者の IP を取り出せるようにする。
#
# 一覧は https://www.cloudflare.com/ips/ （https://www.cloudflare.com/ips-v4 ・ ips-v6）。めったに変わらないが、
# 変わったときはここを更新する。範囲から漏れた拠点を通るリクエストは、今までどおり Cloudflare の IP で扱われるだけで、
# 信頼する範囲が広がることはない。
module CloudflareIpRanges
  RANGES = %w[
    173.245.48.0/20
    103.21.244.0/22
    103.22.200.0/22
    103.31.4.0/22
    141.101.64.0/18
    108.162.192.0/18
    190.93.240.0/20
    188.114.96.0/20
    197.234.240.0/22
    198.41.128.0/17
    162.158.0.0/15
    104.16.0.0/13
    104.24.0.0/14
    172.64.0.0/13
    131.0.72.0/22
    2400:cb00::/32
    2606:4700::/32
    2803:f800::/32
    2405:b500::/32
    2405:8100::/32
    2a06:98c0::/29
    2c0f:f248::/32
  ].map { |range| IPAddr.new(range) }.freeze

  def self.include?(ip)
    address = IPAddr.new(ip.to_s)
    RANGES.any? { |range| range.family == address.family && range.include?(address) }
  rescue IPAddr::Error
    false
  end
end

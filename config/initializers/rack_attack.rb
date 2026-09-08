# frozen_string_literal: true

require 'ipaddr'

# 再起動をまたいでスロットリング・ブロックリストの状態を保持するため Redis ベースの
# キャッシュを使う（デフォルトのインメモリストアだと OOM 再起動のたびにカウンターが
# リセットされ、クローラーが再び閾値までリクエストを通せてしまう）
Rack::Attack.cache.store = Rails.cache

# IPごとのスロットルを、IPをローテーションしながら大量にリクエストを送ることで
# すり抜けようとするスクレイパー対策に使う。同一サブネット（IPv4は/24、IPv6は/64）
# をひとまとめのキーとして扱う（issue #1439）。
subnet_key = lambda do |ip|
  addr = IPAddr.new(ip)
  addr.ipv4? ? addr.mask(24).to_s : addr.mask(64).to_s
rescue IPAddr::Error
  ip
end

# オートコンプリート・全文検索: IP ごとに 60 秒間 30 リクエストまで
Rack::Attack.throttle('search/ip', limit: 30, period: 60) do |req|
  req.ip if req.path.start_with?('/people/search', '/units/search', '/search')
end

# /people, /units の q・tag_ids 絞り込みリクエストか判定する
# tag_ids は組み合わせが事実上無限大になり、ILIKE 全文検索と合わさって重いクエリになる
people_units_filter_request = lambda do |req|
  req.get? && %w[/people /units].include?(req.path) &&
    (req.params['q'].present? || req.params['tag_ids'].present?)
end

# 既知の AI/SEO クローラーは絞り込み検索の組み合わせクロールから得るものがなく、
# 重いクエリを大量に発生させるため、クエリ実行前に即座にブロックする
crawler_ua_pattern = /GPTBot|ChatGPT-User|CCBot|Amazonbot|ClaudeBot|anthropic-ai|Bytespider|PerplexityBot|Google-Extended|Applebot-Extended/i
Rack::Attack.blocklist('block_crawlers/people_units_filter') do |req|
  people_units_filter_request.call(req) && req.user_agent.to_s.match?(crawler_ua_pattern)
end

# ブロックリスト対象外のクライアントも IP ごとに 60 秒間 5 リクエストまでに制限する
# （プレーンな一覧表示・ページネーションは対象外）
Rack::Attack.throttle('people_units_filter/ip', limit: 5, period: 60) do |req|
  req.ip if people_units_filter_request.call(req)
end

# タグ組み合わせを変えながら IP をローテーションし、上記の IP 単位のスロットルを
# すり抜けようとするスクレイパー対策。同一サブネットからのリクエストをまとめて
# 60 秒間 20 リクエストまでに制限する（issue #1439）。共有NAT等からの正規利用も
# 考慮し、IP単位の閾値（5）より緩めに設定している。
Rack::Attack.throttle('people_units_filter/subnet', limit: 20, period: 60) do |req|
  subnet_key.call(req.ip) if people_units_filter_request.call(req)
end

# ログイン: IP ごとに 20 秒間 5 回まで（ブルートフォース対策）
Rack::Attack.throttle('login/ip', limit: 5, period: 20) do |req|
  req.ip if req.path == '/login' && req.post?
end

# ログイン: メールアドレスごとに 60 秒間 10 回まで（IP 偽装対策）
Rack::Attack.throttle('login/email', limit: 10, period: 60) do |req|
  req.params['email']&.downcase if req.path == '/login' && req.post?
end

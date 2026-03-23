# frozen_string_literal: true

# オートコンプリート・全文検索: IP ごとに 60 秒間 30 リクエストまで
Rack::Attack.throttle('search/ip', limit: 30, period: 60) do |req|
  req.ip if req.path.start_with?('/people/search', '/units/search', '/search')
end

# ログイン: IP ごとに 20 秒間 5 回まで（ブルートフォース対策）
Rack::Attack.throttle('login/ip', limit: 5, period: 20) do |req|
  req.ip if req.path == '/login' && req.post?
end

# ログイン: メールアドレスごとに 60 秒間 10 回まで（IP 偽装対策）
Rack::Attack.throttle('login/email', limit: 10, period: 60) do |req|
  req.params['email']&.downcase if req.path == '/login' && req.post?
end

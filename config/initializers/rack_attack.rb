# frozen_string_literal: true

# オートコンプリート・全文検索: IP ごとに 60 秒間 30 リクエストまで
Rack::Attack.throttle('search/ip', limit: 30, period: 60) do |req|
  req.ip if req.path.start_with?('/people/search', '/units/search', '/search')
end

# /people, /units の q・tag_ids 絞り込み: IP ごとに 60 秒間 20 リクエストまで
# tag_ids は組み合わせが事実上無限大になり、ILIKE 全文検索と合わさって重いクエリになるため、
# クローラーによる総当たりクロールから保護する（プレーンな一覧表示・ページネーションは対象外）
Rack::Attack.throttle('people_units_filter/ip', limit: 20, period: 60) do |req|
  req.ip if req.get? && %w[/people /units].include?(req.path) &&
            (req.params['q'].present? || req.params['tag_ids'].present?)
end

# ログイン: IP ごとに 20 秒間 5 回まで（ブルートフォース対策）
Rack::Attack.throttle('login/ip', limit: 5, period: 20) do |req|
  req.ip if req.path == '/login' && req.post?
end

# ログイン: メールアドレスごとに 60 秒間 10 回まで（IP 偽装対策）
Rack::Attack.throttle('login/email', limit: 10, period: 60) do |req|
  req.params['email']&.downcase if req.path == '/login' && req.post?
end

# frozen_string_literal: true

# 再起動をまたいでスロットリング・ブロックリストの状態を保持するため Redis ベースの
# キャッシュを使う（デフォルトのインメモリストアだと OOM 再起動のたびにカウンターが
# リセットされ、クローラーが再び閾値までリクエストを通せてしまう）
Rack::Attack.cache.store = Rails.cache

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

# tag_ids を4カテゴリ以上同時に指定するリクエストか判定する。tag_idsで絞り込める
# グループは現状のUIで people 最大1（個人カナ索引）・units 最大3（カナ索引/地域/
# バンド状態）までしかなく、4カテゴリ以上は通常のユーザー操作では発生し得ない、
# フィルターの組み合わせを総当たりで列挙するクロール特有のパターン（issue #1439）。
excessive_tag_filter_request = lambda do |req|
  next false unless people_units_filter_request.call(req)

  tag_ids = req.params['tag_ids']
  tag_ids.is_a?(Hash) && tag_ids.size >= 4
end

# IPをローテーションしながら大量にリクエストを送ることで、上記の IP 単位のスロットルを
# すり抜けようとするスクレイパー対策（issue #1439）。当初はスロットル（30秒10回まで）
# だったが、その「許可される10回」だけでも本番の同時実行数（Pumaスレッド。
# render.yamlのWEB_CONCURRENCY=1・RAILS_MAX_THREADS=5）を瞬間的に圧迫し、
# 無関係なページまで応答遅延を起こす問題が起きた（issue #1478）。UIでは絶対に
# 発生しないリクエストなので正規ユーザーへの影響はなく、スロットルではなく
# 即座にブロックする。
Rack::Attack.blocklist('block_excessive_tag_combo/people_units_filter') do |req|
  excessive_tag_filter_request.call(req)
end

# ログイン: IP ごとに 20 秒間 5 回まで（ブルートフォース対策）
Rack::Attack.throttle('login/ip', limit: 5, period: 20) do |req|
  req.ip if req.path == '/login' && req.post?
end

# ログイン: メールアドレスごとに 60 秒間 10 回まで（IP 偽装対策）
Rack::Attack.throttle('login/email', limit: 10, period: 60) do |req|
  req.params['email']&.downcase if req.path == '/login' && req.post?
end

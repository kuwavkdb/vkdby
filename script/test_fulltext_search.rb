# frozen_string_literal: true

# 全文検索のテスト
puts '=== PostgreSQL全文検索テスト ==='
puts

# Wikipageモデルを定義
class Wikipage < ActiveRecord::Base
end

# テスト1: ILIKE検索（pg_trgmインデックスを使用）
puts '--- テスト1: ILIKE検索 ---'
start_time = Time.now
results = Wikipage.where('wiki ILIKE ?', '%ボーカル%').limit(10)
elapsed = Time.now - start_time
puts "検索結果: #{results.count}件"
puts "実行時間: #{(elapsed * 1000).round(2)}ms"
puts "サンプル: #{results.first&.name}" if results.any?
puts

# テスト2: 複数キーワード検索
puts '--- テスト2: 複数キーワード検索 ---'
start_time = Time.now
results = Wikipage.where('wiki ILIKE ? OR wiki ILIKE ?', '%ギター%', '%ベース%').limit(10)
elapsed = Time.now - start_time
puts "検索結果: #{results.count}件"
puts "実行時間: #{(elapsed * 1000).round(2)}ms"
puts

# テスト3: 特定のwikipageを検索
puts '--- テスト3: 特定レコード検索 (ID=30) ---'
wikipage = Wikipage.find_by(id: 30)
if wikipage
  puts "ID: #{wikipage.id}"
  puts "名前: #{wikipage.name}"
  puts "タイトル: #{wikipage.title}"
  puts "Wiki内容: #{wikipage.wiki&.slice(0, 100)}..."
else
  puts 'ID=30のレコードが見つかりません'
end
puts

# テスト4: 全レコード数確認
puts '--- テスト4: 全レコード数確認 ---'
total_count = Wikipage.count
puts "総レコード数: #{total_count}件"
puts

puts '=== テスト完了 ==='

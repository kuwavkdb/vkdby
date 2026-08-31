# frozen_string_literal: true

namespace :custom_pages do
  desc 'old_keyが空文字列(\'\')で保存されているCustomPageをNULLに正規化する（issue #1305）'
  task fix_blank_old_key: :environment do
    dry_run = ENV['DRY_RUN'].present?

    scope = CustomPage.with_discarded.where(old_key: '')
    total = scope.count
    puts "対象: #{total}件#{dry_run ? ' (DRY RUN)' : ''}"

    scope.find_each do |page|
      puts "- ##{page.id} key=#{page.key}"
      # 単純にNULLへ正規化するだけでバリデーション/コールバックは不要なため、update_columnを使用
      page.update_column(:old_key, nil) unless dry_run
    end

    puts "\n完了。#{dry_run ? '対象' : '更新'}: #{total}件"
  end
end

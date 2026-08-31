# frozen_string_literal: true

namespace :items do
  desc 'Replace the old Amazon associate tag baked into items.link_url with the currently configured tag (issue #1300)'
  task fix_amazon_associate_tag: :environment do
    old_tag = ENV.fetch('OLD_AMAZON_ASSOCIATE_TAG', 'vkdb-22')
    new_tag = ENV.fetch('NEW_AMAZON_ASSOCIATE_TAG', Rails.application.config.amazon_associate_tag)
    dry_run = ENV['DRY_RUN'].present?

    if old_tag == new_tag
      puts "OLD_AMAZON_ASSOCIATE_TAG (#{old_tag}) と置換先タグ (#{new_tag}) が同じのため、何もしません。"
      next
    end

    scope = Item.with_discarded.where('link_url LIKE ?', "%/#{old_tag}/%")
    total = scope.count
    puts "対象: #{total}件 (旧タグ '#{old_tag}' -> 新タグ '#{new_tag}'#{dry_run ? ' / DRY RUN' : ''})"

    updated = 0
    scope.find_each do |item|
      new_url = item.link_url.sub("/#{old_tag}/", "/#{new_tag}/")
      next if new_url == item.link_url

      unless dry_run
        # 単純な部分文字列の置換のみで一意性の関係は変わらないため、update_columnでバリデーション/コールバックを省略
        item.update_column(:link_url, new_url)
      end

      updated += 1
      print '.' if (updated % 100).zero?
    end

    puts "\n完了。#{dry_run ? '対象' : '更新'}: #{updated} / #{total}件"
  end
end

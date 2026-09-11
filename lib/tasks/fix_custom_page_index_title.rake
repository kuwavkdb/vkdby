# frozen_string_literal: true

namespace :custom_pages do
  desc 'トップページ(key: "index")のtitleに含まれる重複したサイト名を取り除く（issue #1252）'
  task fix_index_title: :environment do
    dry_run = ENV['DRY_RUN'].present?
    site_name = Rails.application.config.site_name

    page = CustomPage.with_discarded.find_by(key: 'index')
    unless page
      puts 'key: "index" のCustomPageが見つかりません。何もしません。'
      next
    end

    # レイアウト側(application_helper#page_title_with_site_name)が末尾にサイト名を
    # 付与する前提のデータへ正規化する。先頭に「サイト名 - 」が付いている場合のみ取り除き、
    # それ以外（想定外の値）は変更しない。
    prefix = "#{site_name} - "
    unless page.title.start_with?(prefix)
      puts "title#{page.title.inspect}は想定した \"#{prefix}...\" 形式ではないため、変更しません。"
      next
    end

    new_title = page.title.delete_prefix(prefix)
    puts "#{dry_run ? '(DRY RUN) ' : ''}##{page.id} title: #{page.title.inspect} -> #{new_title.inspect}"
    page.update_column(:title, new_title) unless dry_run

    puts "\n完了。"
  end
end

# frozen_string_literal: true

# Issue#1086: page_type=custom_page に仕訳された Wikipage から CustomPage の下書きを
# 生成するタスク。ローカル環境での実行を想定している（本番DBとは分離されているため、
# ここで作った下書きは人手で本番の管理画面へコピー＆ペーストして仕上げる運用）。
namespace :custom_page_drafts do
  desc '仕訳済み(page_type=custom_page)のWikipageからCustomPage下書きを生成する'
  task generate: :environment do
    wikipage_id = ENV['WIKIPAGE_ID']
    preview = ENV['PREVIEW'] == '1'

    scope = WikiPageImport.where(page_type: 'custom_page').includes(:wikipage)
    scope = scope.where(wikipage_id: wikipage_id) if wikipage_id

    output_dir = Rails.root.join('tmp/custom_page_drafts')
    FileUtils.mkdir_p(output_dir)

    puts "Target: #{scope.count} records"
    puts "Output: #{output_dir}"
    puts 'Mode: PREVIEW (ローカルDBにも active:false のCustomPageを作成/更新します)' if preview

    generated = 0
    skipped = 0

    scope.find_each do |wpi|
      wp = wpi.wikipage
      unless wp
        puts "[SKIP] WikiPageImport##{wpi.id}: wikipage not found"
        skipped += 1
        next
      end

      if wp.wiki.blank?
        puts "[SKIP] #{wp.name} (ID: #{wp.id}): 本文なし"
        skipped += 1
        next
      end

      draft = CustomPageDraftGenerator.generate(wp)
      write_draft_file(output_dir, draft)
      upsert_preview_custom_page(draft) if preview

      generated += 1
      puts "[GENERATED] #{wp.title || wp.name} (ID: #{wp.id})#{' [要手動対応あり]' if draft.warnings.any?}"
    end

    puts 'Done!'
    puts "  Generated: #{generated}"
    puts "  Skipped:   #{skipped}"
  end
end

def write_draft_file(output_dir, draft)
  filename = "#{draft.wikipage_id}_#{draft.title.to_s.gsub(/[^\p{Word}-]/, '-')}.md"
  path = output_dir.join(filename)

  File.write(path, <<~MARKDOWN)
    <!--
    wikipage_id: #{draft.wikipage_id}
    key(仮):      #{draft.key}
    title:        #{draft.title}
    old_key:      #{draft.old_key}
    #{draft.warnings.map { |w| "warning:      #{w}" }.join("\n")}
    -->

    #{draft.body}
  MARKDOWN
end

def upsert_preview_custom_page(draft)
  page = CustomPage.with_discarded.find_or_initialize_by(key: draft.key)
  page.title = draft.title
  page.body = draft.body
  page.active = false
  page.save!
end

# frozen_string_literal: true

# スキップログにカテゴリーを出力する対象
SKIP_LOG_CATEGORIES = [
  'ライブハウス・ホール',
  'オムニバス'
].freeze

# コメント行・区切り行・リスト行を除いた実質的な内容行を返す
def effective_lines(wikipage)
  wikipage.wiki.to_s.lines
          .reject { |l| l.strip.empty? || l.start_with?('//') || l.start_with?('*') || l.strip == '----' }
end

# リダイレクト・移動ページかどうかを判定する
# 「に移動しました」を含む行がある、または全有効行が「→ [[」で始まる場合に true
def moved_page?(wikipage)
  lines = effective_lines(wikipage)
  return false if lines.empty?

  moved_keyword = "\u306b\u79fb\u52d5\u3057\u307e\u3057\u305f" # に移動しました
  return true if lines.any? { |l| l.include?(moved_keyword) }

  # 全有効行が → [[ で始まる（ページ全体がリダイレクトのみ）
  lines.all? { |l| l.match?(/^\u2192\s*\[\[/) }
end

# {{include ...}} のみで構成されるページかどうかを判定する
def include_only?(wikipage)
  lines = effective_lines(wikipage)
  return false if lines.empty?

  lines.all? { |l| l.match?(/\A\{\{include\s+/i) }
end

def extract_categories(wikipage)
  return [] if wikipage.wiki.blank?

  categories = []
  wikipage.wiki.scan(/\{\{category\s+(.*?)\}\}/i) do |match|
    match[0].split(',').each do |cat|
      categories << cat.strip
    end
  end
  categories
end

def update_wiki_page_import_as_imported(wikipage, page_type:, target:)
  wpi = WikiPageImport.find_or_create_by!(wikipage_id: wikipage.id)
  wpi.update!(
    status: 'imported',
    page_type: page_type,
    import_target: target,
    last_imported_at: Time.current
  )
end

def update_wiki_page_import_as_skipped(wikipage, note:, page_type: nil)
  wpi = WikiPageImport.find_or_create_by!(wikipage_id: wikipage.id)
  return unless wpi.status == 'pending' || (page_type.present? && wpi.page_type.nil?)

  attrs = { status: 'skipped', note: note }
  attrs[:page_type] = page_type if page_type
  wpi.update!(attrs)
end

def format_skip_log(wikipage)
  base_log = "[SKIPPED] #{wikipage.title} (ID: #{wikipage.id})"

  categories = extract_categories(wikipage)
  relevant_cats = categories & SKIP_LOG_CATEGORIES

  if relevant_cats.any?
    "#{base_log} [Category: #{relevant_cats.join(', ')}]"
  else
    base_log
  end
end

namespace :import do # rubocop:disable Metrics/BlockLength
  desc 'Import units from Wikipages'
  task units: :environment do
    puts 'Starting unit import from Wikipages...'
    count = 0
    skipped = 0

    query = Wikipage.all
    if ENV['ID']
      query = query.where(id: ENV['ID'])
      puts "Targeting single ID: #{ENV['ID']}"
    elsif ENV['START']
      query = query.where('id >= ?', ENV['START'])
      puts "Starting from ID: #{ENV['START']}"
    end

    limit = ENV['LIMIT']&.to_i
    puts "Limit: #{limit}" if limit

    query.find_each.with_index do |wp, _index|
      break if limit && count >= limit

      if WikipageImporter.ignored?(wp)
        skipped += 1
        # Silent skip for ignored pages
        next
      elsif WikipageImporter.valid_unit?(wp)
        WikipageImporter.import(wp)
        count += 1
      else
        skipped += 1
        # 個人候補の場合はログ出力しない
        puts format_skip_log(wp) if wp.title.present? && !PersonImporter.valid_person?(wp)
      end
    end

    puts 'Import complete!'
    puts "  Imported: #{count} units"
    puts "  Skipped:  #{skipped} pages"
  end

  desc 'Import people from Wikipages'
  task people: :environment do
    mode = ENV['MODE']
    manual_mode  = mode == 'MANUAL'
    skipped_mode = mode == 'SKIPPED'

    unless manual_mode || skipped_mode || mode == 'ALL' || ENV['ID'] || ENV['START']
      puts 'Error: 実行条件を指定してください。'
      puts '  MODE=ALL       全件対象'
      puts '  MODE=MANUAL    手動仕訳済みページのみ'
      puts '  MODE=SKIPPED   スキップ済みページのみ再処理'
      puts '  ID=<id>        指定 ID のみ'
      puts '  START=<id>     指定 ID 以降'
      exit 1
    end

    puts 'Starting person import from Wikipages...'
    puts 'Mode: MANUAL (page_type=person の手動設定済みページのみ)' if manual_mode
    puts 'Mode: SKIPPED (スキップ済みページのみ再処理)' if skipped_mode
    count = 0
    skipped = 0

    if manual_mode
      query = WikiPageImport.manually_set.where(page_type: 'person').includes(:wikipage)
    elsif skipped_mode
      query = WikiPageImport.skipped.where(page_type: [nil, 'person']).includes(:wikipage)
    else
      query = Wikipage.all
      if ENV['ID']
        query = query.where(id: ENV['ID'])
        puts "Targeting single ID: #{ENV['ID']}"
      elsif ENV['START']
        query = query.where('id >= ?', ENV['START'])
        puts "Starting from ID: #{ENV['START']}"
      end
    end

    limit = ENV['LIMIT']&.to_i
    puts "Limit: #{limit}" if limit

    if manual_mode || skipped_mode
      query.find_each do |wpi|
        break if limit && count >= limit

        wp = wpi.wikipage
        unless wp
          puts "[SKIP] WikiPageImport##{wpi.id}: wikipage not found"
          next
        end

        if skipped_mode && !PersonImporter.valid_person?(wp)
          puts "[SKIP] #{wp.title} (ID: #{wp.id}): valid_person? returned false"
          next
        end

        PersonImporter.import(wp)
        count += 1
        puts "[IMPORTED] #{wp.title} (ID: #{wp.id})"

        person = Person.find_by(old_wiki_id: wp.id)
        update_wiki_page_import_as_imported(wp, page_type: 'person', target: person)
      end
    else
      query.find_each.with_index do |wp, _index|
        break if limit && count >= limit

        if PersonImporter.ignored?(wp)
          skipped += 1
          update_wiki_page_import_as_skipped(wp, note: 'ignored')
          next
        elsif moved_page?(wp)
          skipped += 1
          update_wiki_page_import_as_skipped(wp, note: 'moved', page_type: 'moved')
          next
        elsif include_only?(wp)
          skipped += 1
          update_wiki_page_import_as_skipped(wp, note: 'include only', page_type: 'other')
          next
        elsif PersonImporter.valid_person?(wp)
          PersonImporter.import(wp)
          count += 1
          person = Person.find_by(old_wiki_id: wp.id)
          update_wiki_page_import_as_imported(wp, page_type: 'person', target: person)
        else
          skipped += 1
          # ユニット候補はunits_v2タスクで処理済みのためスキップ対象外
          unless WikipageImporter.valid_unit?(wp)
            update_wiki_page_import_as_skipped(wp, note: 'not a unit or person')
            puts format_skip_log(wp) if wp.title.present?
          end
        end
      end
    end

    puts 'Import complete!'
    puts "  Imported: #{count} people"
    puts "  Skipped:  #{skipped} pages" unless manual_mode || skipped_mode || ENV['ID']
  end

  desc 'Reset all imported data'
  task reset: :environment do
    puts 'Reseting imported data...'

    ActiveRecord::Base.transaction do
      puts 'Deleting UnitPeople...'
      UnitPerson.delete_all

      puts 'Deleting UnitLogs...'
      UnitLog.delete_all

      puts 'Deleting TagIndexItems...'
      TagIndexItem.delete_all

      puts 'Deleting Links...'
      Link.delete_all

      puts 'Deleting People...'
      Person.delete_all

      puts 'Deleting Units...'
      Unit.delete_all

      puts 'Deleting TagIndices (Group 1 & 2)...'
      # Assuming 1=Unit, 2=Person tags based on import logic
      TagIndex.where(index_group_id: [1, 2]).delete_all
    end

    puts 'Reset complete!'
  end

  desc 'Truncate units and people tables'
  task truncate_units_and_people: :environment do
    sql = 'TRUNCATE TABLE units, people, unit_persons, unit_snapshots, snapshot_people, ' \
          'sections, links, tag_indices RESTART IDENTITY CASCADE'
    ActiveRecord::Base.connection.execute(sql)
    puts '✅ Truncated units, people, unit_persons, unit_snapshots, snapshot_people, ' \
         'sections, links, tag_indices tables'
  end

  desc 'Truncate trends and items tables'
  task truncate_trends_and_items: :environment do
    ActiveRecord::Base.connection.execute('TRUNCATE TABLE trends, items RESTART IDENTITY CASCADE')
    puts '✅ Truncated trends and tables tables'
  end
end

# frozen_string_literal: true

namespace :import do
  desc 'Import units with snapshots from Wikipages (V2)'
  task units_v2: :environment do
    puts 'Starting unit import with snapshots from Wikipages (V2)...'
    count = 0
    skipped = 0
    snapshots_created = 0

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
        next
      elsif WikipageImporter.valid_unit?(wp)
        # ID指定時: インポート前に既存の関連レコードを削除
        if ENV['ID']
          existing_unit = Unit.find_by(old_wiki_id: wp.id)
          if existing_unit
            sections_count = existing_unit.sections.count
            links_count = existing_unit.links.count
            existing_unit.sections.destroy_all
            existing_unit.links.destroy_all
            puts "  Pre-delete: #{sections_count} sections, #{links_count} links (#{existing_unit.name})"
          end
        end

        # V2 importer を使用
        WikipageImporterV2.import(wp)
        count += 1

        # 作成されたスナップショット数をカウント
        unit = Unit.find_by(old_wiki_id: wp.id)
        snapshots_created += unit.unit_snapshots.count if unit
      else
        skipped += 1
        puts format_skip_log(wp) if wp.title.present? && !PersonImporter.valid_person?(wp)
      end
    end

    puts 'Import complete!'
    puts "  Imported: #{count} units"
    puts "  Snapshots created: #{snapshots_created}"
    puts "  Skipped:  #{skipped} pages"
  end
end

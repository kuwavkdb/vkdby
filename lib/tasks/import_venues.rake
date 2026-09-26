# frozen_string_literal: true

def venue_dry_run_sample_line(wikipage)
  importer = VenueImporter.new(wikipage)
  importer.send(:preprocess_content)
  heading_line = importer.instance_variable_get(:@wiki_content).lines.find { |l| l.strip.start_with?('!') }
  first_line = heading_line&.strip&.gsub(/^!+/, '')&.strip&.gsub(/[（(]\s*[）)]/, '')
  parsed = importer.send(:parse_venue_names_from_first_line, first_line)
  address = importer.send(:extract_address)
  prefecture = importer.send(:extract_prefecture)
  "  id=#{wikipage.id} name=#{parsed[:name].inspect} kana=#{parsed[:name_kana].inspect} " \
    "address=#{address.inspect} prefecture=#{prefecture.inspect}"
end

namespace :import do
  desc 'Import venues from Wikipages (ライブハウス・ホール)'
  task venues: :environment do
    dry_run = ENV['DRY_RUN'] == '1'
    mode = ENV['MODE']
    manual_mode  = mode == 'MANUAL'
    skipped_mode = mode == 'SKIPPED'
    reload_mode  = mode == 'RELOAD'

    unless dry_run || manual_mode || skipped_mode || reload_mode || mode == 'ALL' || ENV['ID']
      puts 'Error: 実行条件を指定してください。'
      puts '  DRY_RUN=1      対象件数・サンプルの確認のみ（DBへの書き込みなし）'
      puts '  MODE=ALL       全件対象'
      puts '  MODE=MANUAL    手動仕訳済みページのみ'
      puts '  MODE=SKIPPED   スキップ済みページのみ再処理'
      puts '  MODE=RELOAD    インポート済みの全Venueを再取り込み'
      puts '  ID=<id>        指定 ID のみ'
      exit 1
    end

    puts 'Starting venue import from Wikipages...'
    puts 'Mode: DRY_RUN (DB への書き込みは行いません)' if dry_run
    puts 'Mode: MANUAL (page_type=live_house の手動設定済みページのみ)' if manual_mode
    puts 'Mode: SKIPPED (スキップ済みページのみ再処理)' if skipped_mode
    puts 'Mode: RELOAD (インポート済みの全Venueを再取り込み)' if reload_mode

    if manual_mode
      query = WikiPageImport.manually_set.where(page_type: 'live_house').includes(:wikipage)
    elsif skipped_mode
      query = WikiPageImport.skipped.where(page_type: [nil, 'live_house']).includes(:wikipage)
    elsif reload_mode
      query = WikiPageImport.imported.where(page_type: 'live_house').includes(:wikipage)
    else
      query = Wikipage.where('wiki LIKE ?', '%{{category ライブハウス・ホール}}%')
      query = query.where(id: ENV['ID']) if ENV['ID']
    end

    limit = ENV['LIMIT']&.to_i
    puts "Limit: #{limit}" if limit

    count = 0
    skipped = 0
    samples = []

    if manual_mode || skipped_mode || reload_mode
      query.find_each do |wpi|
        break if limit && count >= limit

        wp = wpi.wikipage
        unless wp
          puts "[SKIP] WikiPageImport##{wpi.id}: wikipage not found"
          next
        end

        next if skipped_mode && !VenueImporter.valid_venue?(wp)

        if dry_run
          count += 1
          samples << wp if samples.size < 5
          next
        end

        if reload_mode
          existing_venue = Venue.find_by(old_wiki_id: wp.id)
          existing_venue&.links&.destroy_all
        end

        venue = VenueImporter.import(wp)
        count += 1
        puts "[IMPORTED] #{wp.title || wp.name} (ID: #{wp.id}) -> Venue##{venue.id} (#{venue.key})"
        update_wiki_page_import_as_imported(wp, page_type: 'live_house', target: venue)
      end
    else
      query.find_each do |wp|
        break if limit && count >= limit

        unless VenueImporter.valid_venue?(wp)
          skipped += 1
          next
        end

        if dry_run
          count += 1
          samples << wp if samples.size < 5
          next
        end

        venue = VenueImporter.import(wp)
        if venue
          count += 1
          puts "[IMPORTED] #{wp.title || wp.name} (ID: #{wp.id}) -> Venue##{venue.id} (#{venue.key})"
          update_wiki_page_import_as_imported(wp, page_type: 'live_house', target: venue)
        else
          skipped += 1
          update_wiki_page_import_as_skipped(wp, note: 'no venue name found', page_type: 'live_house')
        end
      end
    end

    if dry_run
      puts "対象件数: #{count}"
      puts 'サンプル:'
      samples.each { |wp| puts venue_dry_run_sample_line(wp) }
    else
      puts 'Import complete!'
      puts "  Imported: #{count} venues"
      puts "  Skipped:  #{skipped} pages" unless manual_mode || skipped_mode || reload_mode
    end
  end
end

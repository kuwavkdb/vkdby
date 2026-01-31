# frozen_string_literal: true

# スキップログにカテゴリーを出力する対象
SKIP_LOG_CATEGORIES = [
  'ライブハウス・ホール',
  'オムニバス'
].freeze

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

namespace :import do
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
    puts 'Starting person import from Wikipages...'
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

      if PersonImporter.ignored?(wp)
        skipped += 1
        # Silent skip for ignored pages
        next
      elsif PersonImporter.valid_person?(wp)
        PersonImporter.import(wp)
        count += 1
      else
        skipped += 1
        # ユニット候補の場合はログ出力しない
        puts format_skip_log(wp) if wp.title.present? && !WikipageImporter.valid_unit?(wp)
      end
    end

    puts 'Import complete!'
    puts "  Imported: #{count} people"
    puts "  Skipped:  #{skipped} pages"
  end

  desc 'Reset all imported data'
  task reset: :environment do
    puts 'Reseting imported data...'

    ActiveRecord::Base.transaction do
      puts 'Deleting UnitPeople...'
      UnitPerson.delete_all

      puts 'Deleting PersonLogs...'
      PersonLog.delete_all

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
end

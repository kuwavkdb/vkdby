# frozen_string_literal: true

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

      if WikipageImporter.valid_unit?(wp)
        WikipageImporter.import(wp)
        count += 1
      else
        skipped += 1
        puts "[SKIPPED] #{wp.title} (ID: #{wp.id})" if wp.title.present?
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

      if PersonImporter.valid_person?(wp)
        PersonImporter.import(wp)
        count += 1
      else
        skipped += 1
        puts "[SKIPPED] #{wp.title} (ID: #{wp.id})" if wp.title.present?
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

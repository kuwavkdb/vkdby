# frozen_string_literal: true

namespace :convert do
  desc 'Convert release_schedules to items'
  task items: :environment do
    puts 'Start converting ReleaseSchedule to Item...'

    # 環境変数による制御
    if ENV['ID']
      # 指定 ID のみをコンバート
      convert_by_id(ENV['ID'].to_i)
    elsif ENV['LIMIT']
      # 指定件数をコンバート
      convert_with_limit(ENV['LIMIT'].to_i)
    else
      # 全件コンバート (truncate してから)
      convert_all
    end
  end

  def convert_all
    puts 'Truncating items table...'
    Item.delete_all

    count = 0
    skipped_count = 0

    ReleaseSchedule.where(type: %w[aitem a2s]).find_each do |rs|
      if convert_record(rs)
        count += 1
        print '.' if (count % 100).zero?
      else
        skipped_count += 1
      end
    end

    puts "\nConversion completed. Imported: #{count}, Skipped: #{skipped_count}"
  end

  def convert_with_limit(limit)
    puts "Converting up to #{limit} records..."

    count = 0
    skipped_count = 0

    ReleaseSchedule.where(type: %w[aitem a2s]).limit(limit).find_each do |rs|
      if convert_record(rs)
        count += 1
        print '.' if (count % 10).zero?
      else
        skipped_count += 1
      end
    end

    puts "\nConversion completed. Imported: #{count}, Skipped: #{skipped_count}"
  end

  def convert_by_id(id)
    puts "Converting ReleaseSchedule ID: #{id}..."

    rs = ReleaseSchedule.find_by(id: id)
    unless rs
      puts "ReleaseSchedule ID #{id} not found."
      return
    end

    if convert_record(rs)
      puts 'Conversion completed successfully.'
    else
      puts 'Conversion failed or skipped.'
    end
  end

  def convert_record(release_schedule)
    attributes = ItemConverter.convert(release_schedule)
    return false unless attributes

    begin
      # link_url でユニーク制約があるため、find_or_initialize_by で検索
      item = Item.find_or_initialize_by(link_url: attributes[:link_url])
      item.assign_attributes(attributes)
      item.save!
      true
    rescue StandardError => e
      puts "\nFailed to save Item (ReleaseSchedule ID: #{release_schedule.id}): #{e.message}"
      false
    end
  end
end

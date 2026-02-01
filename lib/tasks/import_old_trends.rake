# frozen_string_literal: true

namespace :import do
  desc 'Import old trends from sql dump'
  task old_trends: :environment do
    require 'date'

    file_path = Rails.root.join('trends_all_20260201.sql')
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      exit
    end

    puts 'Start importing OldTrend...'
    OldTrend.delete_all

    count = 0
    File.foreach(file_path) do |line|
      line = line.strip
      # Only process lines starting with ( which are value lines
      next unless line.start_with?('(')

      # Remove leading ( and trailing ), or );
      content = line.sub(/^\(/, '').sub(/\)[,;]$/, '')

      # Split by comma via regex to respect quotes
      # Regex explanation:
      # '((?:[^']|'')*)'  => Match quoted string, allowing '' as escaped quote. Capture inside group 1.
      # ([^,]+)           => Match non-quoted values (numbers, NULL)
      # ,                 => Separator
      values = []
      scanner = StringScanner.new(content)

      until scanner.eos?
        if scanner.scan(/'((?:[^']|'')*)'/)
          # Quoted string: unescape '' to '
          values << scanner[1].gsub("''", "'")
        elsif scanner.scan(/NULL/)
          values << nil
        elsif scanner.scan(/([^,]+)/)
          val = scanner[1].strip
          # Handle numbers
          values << if val =~ /^\d+$/
                      val.to_i
                    else
                      val
                    end
        end

        scanner.scan(/,\s*/)
      end

      # Expected 16 columns
      # `id`, `wikipage_id`, `target_name`, `target_date`, `content`
      # `quote`, `quote_url`, `via`, `via_url`, `created_at`, `updated_at`
      # `publish`, `publish_plan_date`, `rss`, `hide_member`, `class`

      if values.length != 16
        puts "Skipping invalid line (col count #{values.length}): #{line}"
        next
      end

      OldTrend.create!(
        id: values[0],
        wikipage_id: values[1],
        target_name: values[2],
        target_date: values[3],
        content: values[4],
        quote: values[5],
        quote_url: values[6],
        via: values[7],
        via_url: values[8],
        created_at: values[9],
        updated_at: values[10],
        publish: values[11] == 1,
        publish_plan_date: values[12],
        rss: values[13] == 1,
        hide_member: values[14],
        trend_class: values[15]
      )
      count += 1
      print '.' if (count % 100).zero?
    end
    puts "\nImported #{count} records."
  end
end

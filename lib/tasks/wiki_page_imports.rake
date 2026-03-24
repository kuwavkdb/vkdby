# frozen_string_literal: true

namespace :wiki_page_imports do
  desc 'Wikipage 全件を wiki_page_imports に pending で登録する（冪等）'
  task seed: :environment do
    puts 'Seeding wiki_page_imports...'
    inserted = 0
    skipped = 0

    Wikipage.find_each do |wp|
      if WikiPageImport.exists?(wikipage_id: wp.id)
        skipped += 1
        next
      end

      WikiPageImport.create!(wikipage_id: wp.id, status: 'pending')
      inserted += 1
    end

    puts 'Done!'
    puts "  Inserted: #{inserted}"
    puts "  Skipped:  #{skipped} (already registered)"
  end
end

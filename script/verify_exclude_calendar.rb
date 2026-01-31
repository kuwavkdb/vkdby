# frozen_string_literal: true

require_relative '../config/environment'

puts '== Starting Calendar Page Exclusion Verification =='

# 1. Create Test Data
puts "\n[1] Creating test Wikipages..."

# Case A: Calendar page (Should be skipped)
wiki_content_calendar = <<~WIKI
  CalendarPage(CalendarPage)
  {{category Band}}
  !Vocal… [[CalVocal]]
WIKI
wp_calendar = Wikipage.create!(name: "カレンダー/#{Time.now.to_i}", title: "カレンダー/#{Time.now.to_i}", wiki: wiki_content_calendar)

# Case B: Normal page (Should be imported)
wiki_content_normal = <<~WIKI
  NormalPage(NormalPage)
  {{category Band}}
  !Vocal… [[NormVocal]]
WIKI
wp_normal = Wikipage.create!(name: "NormalPage_#{Time.now.to_i}", title: "NormalPage_#{Time.now.to_i}", wiki: wiki_content_normal)

# 2. Run Import
puts "\n[2] Running WikipageImporter..."

puts "Importing Calendar Page: #{wp_calendar.name}"
WikipageImporter.import(wp_calendar)

puts "Importing Normal Page: #{wp_normal.name}"
WikipageImporter.import(wp_normal)

# 3. Verify Results
puts "\n[3] Verifying results..."

# Check Calendar Page (Should NOT exist as Unit)
unit_calendar = Unit.find_by(old_wiki_id: wp_calendar.id)
if unit_calendar
  puts "FAIL: Calendar Unit found (Should have been skipped): #{unit_calendar.name}"
  exit 1
else
  puts 'PASS: Calendar Unit not found (Correctly skipped)'
end

# Check Normal Page (Should exist as Unit)
unit_normal = Unit.find_by(old_wiki_id: wp_normal.id)
if unit_normal
  puts "PASS: Normal Unit found: #{unit_normal.name}"
else
  puts 'FAIL: Normal Unit not found (Should have been imported)'
  exit 1
end

puts "\nVerification Successful!"

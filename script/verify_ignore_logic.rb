# frozen_string_literal: true

require_relative '../config/environment'

puts '== Starting Ignore Logic Verification =='

# 1. Test Data Setup
calendar_wp = Wikipage.new(title: 'カレンダー/2026', name: 'カレンダー/2026', wiki: 'dummy')
official_wp = Wikipage.new(title: 'オフィシャルサイト/XYZ', name: 'オフィシャルサイト/XYZ', wiki: 'dummy')
indies_wp = Wikipage.new(title: 'インディーズ/Label', name: 'インディーズ/Label', wiki: 'dummy')
comment_wp = Wikipage.new(title: 'SomePage_comment', name: 'SomePage_comment', wiki: 'dummy')
normal_wp = Wikipage.new(title: 'SomeBand', name: 'SomeBand', wiki: 'dummy')

# 2. Verify WikipageImporter.ignored?
puts "\n[Checking WikipageImporter.ignored?]"

[calendar_wp, official_wp, indies_wp, comment_wp].each do |wp|
  if WikipageImporter.ignored?(wp)
    puts "  PASS: '#{wp.title}' is ignored."
  else
    puts "  FAIL: '#{wp.title}' should be ignored."
  end
end

if WikipageImporter.ignored?(normal_wp)
  puts "  FAIL: 'SomeBand' should NOT be ignored."
else
  puts "  PASS: 'SomeBand' is NOT ignored."
end

# 3. Verify WikipageImporter.valid_unit? behavior
# If ignored? is true, valid_unit? should return false (implied via our change)
puts "\n[Checking WikipageImporter.valid_unit?]"

if WikipageImporter.valid_unit?(calendar_wp)
  puts "  FAIL: 'カレンダー/2026' is valid unit (should be false because it is ignored)."
else
  puts "  PASS: 'カレンダー/2026' is not valid unit."
end

puts "\nVerification Complete"

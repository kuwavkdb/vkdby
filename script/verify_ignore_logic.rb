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

  # 3. Verify valid_unit? / valid_person? behavior
  if WikipageImporter.valid_unit?(wp)
    puts "  FAIL (Unit): '#{wp.title}' is valid unit (should be false)."
  else
    puts "  PASS (Unit): '#{wp.title}' is NOT valid unit."
  end

  if PersonImporter.valid_person?(wp)
    puts "  FAIL (Person): '#{wp.title}' is valid person (should be false)."
  else
    puts "  PASS (Person): '#{wp.title}' is NOT valid person."
  end
end

puts "\n[Checking Normal Page]"
if WikipageImporter.ignored?(normal_wp)
  puts "  FAIL: 'SomeBand' should NOT be ignored."
else
  puts "  PASS: 'SomeBand' is NOT ignored."
end

puts "\nVerification Complete"

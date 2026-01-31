# frozen_string_literal: true

require_relative '../config/environment'

puts '== Starting Support Member Import Verification =='

# 1. Create Test Data
puts "\n[1] Creating test Wikipage..."
wiki_content = <<~WIKI
  SupportUnitTest(SupportUnitTest)
  {{category Band}}
  !Support Drums… [[SupportDrummer]]
  !サポート Guitar… [[SupportGuitarist]]
  !Vocal… [[RegularVocalist]]
WIKI

wp = Wikipage.create!(name: "SupportUnitTest_#{Time.now.to_i}", title: 'SupportUnitTest', wiki: wiki_content)

# 2. Run Import
puts "\n[2] Running WikipageImporter..."
WikipageImporter.import(wp)

# 3. Verify Results
puts "\n[3] Verifying results..."

puts "Debug: Units: #{Unit.where('name LIKE ?', 'SupportUnitTest%').pluck(:id, :name, :key)}"
unit = Unit.find_by(old_wiki_id: wp.id)
if unit
  puts "Debug: UnitPeople: #{unit.unit_people.pluck(:person_name, :part, :support)}"
else
  puts 'Debug: Unit not found'
end

unless unit
  puts 'ERROR: Unit not found!'
  exit 1
end

# Check Support Drummer
drummer = unit.unit_people.find_by(person_name: 'SupportDrummer')
if drummer
  puts "Drummer: part=#{drummer.part}, support=#{drummer.support}"
  if drummer.part == 'drums' && drummer.support == true
    puts '  -> OK'
  else
    puts '  -> FAIL'
  end
else
  puts 'ERROR: SupportDrummer not found'
end

# Check Support Guitarist
guitarist = unit.unit_people.find_by(person_name: 'SupportGuitarist')
if guitarist
  puts "Guitarist: part=#{guitarist.part}, support=#{guitarist.support}"
  if guitarist.part == 'guitar' && guitarist.support == true
    puts '  -> OK'
  else
    puts '  -> FAIL'
  end
else
  puts 'ERROR: SupportGuitarist not found'
end

# Check Regular Vocalist
vocalist = unit.unit_people.find_by(person_name: 'RegularVocalist')
if vocalist
  puts "Vocalist: part=#{vocalist.part}, support=#{vocalist.support}"
  if vocalist.part == 'vocal' && vocalist.support == false
    puts '  -> OK'
  else
    puts '  -> FAIL'
  end
else
  puts 'ERROR: RegularVocalist not found'
end

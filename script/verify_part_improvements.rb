# frozen_string_literal: true

require_relative '../config/environment'

puts '== Starting Part Import Improvements Verification =='

# 1. Create Test Data
puts "\n[1] Creating test Wikipage..."
wiki_content = <<~WIKI
  PartTestUnit(PartTestUnit)
  {{category Band}}
  !Vocal… [[BangVocal]]
  !UnknownPart… [[BangUnknown]]
  !MyUnknownPart… [[PlainUnknown]]
  !Support Unknown… [[BangSupportUnknown]]
WIKI

wp = Wikipage.create!(name: "PartTestUnit_#{Time.now.to_i}", title: 'PartTestUnit', wiki: wiki_content)

# 2. Run Import
puts "\n[2] Running WikipageImporter..."
WikipageImporter.import(wp)

# 3. Verify Results
puts "\n[3] Verifying results..."
unit = Unit.find_by(old_wiki_id: wp.id)

unless unit
  puts "Debug: All Units: #{Unit.where('name LIKE ?', 'PartTestUnit%').pluck(:id, :name, :old_wiki_id)}"
  puts 'ERROR: Unit not found!'
  exit 1
end

puts "Debug: UnitPeople: #{unit.unit_people.pluck(:person_name, :part, :part_alias, :support)}"

# Check !Vocal -> part: :vocal, alias: nil
bang_vocal = unit.unit_people.find_by(person_name: 'BangVocal')
if bang_vocal
  puts "BangVocal: part=#{bang_vocal.part}, alias=#{bang_vocal.part_alias.inspect}"
  if bang_vocal.part == 'vocal' && bang_vocal.part_alias.nil?
    puts '  -> OK'
  else
    puts '  -> FAIL'
  end
else
  puts 'ERROR: BangVocal not found'
end

# Check !UnknownPart -> part: :unknown, alias: "UnknownPart" (bang removed)
bang_unknown = unit.unit_people.find_by(person_name: 'BangUnknown')
if bang_unknown
  puts "BangUnknown: part=#{bang_unknown.part}, alias=#{bang_unknown.part_alias.inspect}"
  if bang_unknown.part == 'unknown' && bang_unknown.part_alias == 'UnknownPart'
    puts '  -> OK'
  else
    puts '  -> FAIL'
  end
else
  puts 'ERROR: BangUnknown not found'
end

# Check MyUnknownPart -> part: :unknown, alias: "MyUnknownPart"
plain_unknown = unit.unit_people.find_by(person_name: 'PlainUnknown')
if plain_unknown
  puts "PlainUnknown: part=#{plain_unknown.part}, alias=#{plain_unknown.part_alias.inspect}"
  if plain_unknown.part == 'unknown' && plain_unknown.part_alias == 'MyUnknownPart'
    puts '  -> OK'
  else
    puts '  -> FAIL'
  end
else
  puts 'ERROR: PlainUnknown not found'
end

# Check !Support Unknown -> part: :unknown, alias: "Unknown" (bang and support removed), support: true
bang_support_unknown = unit.unit_people.find_by(person_name: 'BangSupportUnknown')
if bang_support_unknown
  puts "BangSupportUnknown: part=#{bang_support_unknown.part}, alias=#{bang_support_unknown.part_alias.inspect}, support=#{bang_support_unknown.support}"
  if bang_support_unknown.part == 'unknown' && bang_support_unknown.part_alias == 'Unknown' && bang_support_unknown.support == true
    puts '  -> OK'
  else
    puts '  -> FAIL'
  end
else
  puts 'ERROR: BangSupportUnknown not found'
end

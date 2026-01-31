# frozen_string_literal: true

require_relative '../config/environment'

puts '== Starting Wiki-style Part Alias Verification =='

# 1. Create Test Data
puts "\n[1] Creating test Wikipage..."
wiki_content = <<~WIKI
  WikiAliasUnit(WikiAliasUnit)
  {{category Band}}
  ![[ボヲカル|Vocal]]… [[AliasVocal]]
  ![[太鼓|Drums]]… [[AliasDrums]]
  ![[G|Guitar]]… [[AliasGuitar]]
  ![[低音|MegaBass]]… [[AliasUnknown]]
  !Support [[Key|Keyboard]]… [[SupportInfoKey]]
WIKI

wp = Wikipage.create!(name: "WikiAliasUnit_#{Time.now.to_i}", title: 'WikiAliasUnit', wiki: wiki_content)

# 2. Run Import
puts "\n[2] Running WikipageImporter..."
WikipageImporter.import(wp)

# 3. Verify Results
puts "\n[3] Verifying results..."
unit = Unit.find_by(old_wiki_id: wp.id)

unless unit
  puts "ERROR: Unit not found (OldWikiID: #{wp.id})"
  exit 1
end

def check_member(unit, name, expected_part, expected_alias, expected_support: false)
  member = unit.unit_people.find_by(person_name: name)
  unless member
    puts "FAIL: Member '#{name}' not found"
    return
  end

  puts "Checking #{name}:"
  puts "  Part: #{member.part} (Expected: #{expected_part})"
  puts "  Alias: #{member.part_alias.inspect} (Expected: #{expected_alias.inspect})"
  puts "  Support: #{member.support} (Expected: #{expected_support})"

  ok_part = member.part == expected_part.to_s
  ok_alias = member.part_alias == expected_alias
  ok_support = member.support == expected_support

  if ok_part && ok_alias && ok_support
    puts '  -> OK'
  else
    puts '  -> FAIL'
  end
end

check_member(unit, 'AliasVocal', :vocal, 'ボヲカル')
check_member(unit, 'AliasDrums', :drums, '太鼓')
check_member(unit, 'AliasGuitar', :guitar, 'G')
check_member(unit, 'AliasUnknown', :unknown, '低音') # "MegaBass" is unknown part key, but wiki alias logic should take '低音' as alias?
# Wait, let's re-read implementation logic.
# cleaned_part_str would be "MegaBass" (group 2). part_key will be :unknown.
# part_alias = part_alias_from_wiki ('低音') || ...
# So alias should be '低音'. And part will be 'unknown'.

check_member(unit, 'SupportInfoKey', :keyboard, 'Key', expected_support: true)

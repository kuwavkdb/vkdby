# frozen_string_literal: true

require_relative '../config/environment'

puts '== Starting UnitPerson Linking Verification =='

# 1. Setup Test Data
puts "\n[1] Setting up test data..."
unit_name = "TestUnit_#{Time.now.to_i}"
unit = Unit.create!(name: unit_name, key: unit_name.downcase)

person_name = "TestPerson_#{Time.now.to_i}"
old_key_raw = "テスト個人_#{Time.now.to_i}"
encoded_old_key = URI.encode_www_form_component(old_key_raw.encode('EUC-JP'))

# Create UnitPerson with matching old_person_key but NO link
up = UnitPerson.create!(
  unit: unit,
  person_name: person_name,
  old_person_key: encoded_old_key,
  part: :vocal,
  status: :active
)

puts "Created UnitPerson (ID: #{up.id})"
puts "  - old_person_key: #{up.old_person_key}"
puts "  - person_id: #{up.person_id.inspect}"
puts "  - person_key: #{up.person_key.inspect}"

# Create Wikipage for the Person
wiki_content = <<~WIKI
  #{old_key_raw}（#{old_key_raw}）
  {{category 個人}}
  {{category 誕生日/1/1}}
WIKI

wikipage = Wikipage.create!(
  name: old_key_raw, # old_key matches here
  title: old_key_raw,
  wiki: wiki_content
)

puts "Created Wikipage (ID: #{wikipage.id}, Name: #{wikipage.name})"

# 2. Run Import
puts "\n[2] Running PersonImporter..."
begin
  PersonImporter.import(wikipage)
rescue StandardError => e
  puts "Import failed: #{e.message}"
  puts e.backtrace.join("\n")
end

# 3. Verify Result
puts "\n[3] Verifying results..."
up.reload
person = Person.find_by(old_key: encoded_old_key)

if person
  puts "Created Person (ID: #{person.id}, Key: #{person.key})"
else
  puts 'ERROR: Person not found!'
  exit 1
end

puts 'Updated UnitPerson:'
puts "  - person_id: #{up.person_id.inspect} (Expected: #{person.id})"
puts "  - person_key: #{up.person_key.inspect} (Expected: #{person.key})"

if up.person_id == person.id && up.person_key == person.key
  puts "\nSUCCESS: UnitPerson was correctly linked to the imported Person!"
else
  puts "\nFAILURE: UnitPerson was NOT correctly linked."
  exit 1
end

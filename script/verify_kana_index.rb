# frozen_string_literal: true

puts "--- Verification Script: Kana Index ---"

# 1. Create Test Data
puts "\n1. Creating Test Data..."
index_a = TagIndex.find_or_create_by!(name: 'あテスト') do |ti|
  ti.index_group = 1
  ti.order_in_group = 1
end

# Ensure index_group is set (in case it existed but was nil)
index_a.update!(index_group: 1) if index_a.index_group != 1

puts "Created/Found TagIndex: ID=#{index_a.id}, Name=#{index_a.name}, Group=#{index_a.index_group}"

# Link a Person
person = Person.first
if person
  TagIndexItem.find_or_create_by!(tag_index_id: index_a.id, indexable: person)
  puts "Linked Person: #{person.name}"
else
  puts "No Person found to link."
end

# Link a Unit
unit = Unit.first
if unit
  TagIndexItem.find_or_create_by!(tag_index_id: index_a.id, indexable: unit)
  puts "Linked Unit: #{unit.name}"
else
  puts "No Unit found to link."
end

# 2. Verify Data Associations
puts "\n2. Verifying Associations..."
puts "Index '#{index_a.name}' has #{index_a.people.count} people and #{index_a.units.count} units."

# 3. Simulate Request to /index/1
puts "\n3. Simulating Request to /index/1..."
app = Rails.application
url_helpers = app.routes.url_helpers
path = url_helpers.indices_group_path(1)
puts "Path: #{path}"

# We can't easily simulate a full HTTP request here without loading integration test helpers,
# but we can check if the route is recognized.
recognized = Rails.application.routes.recognize_path(path)
puts "Route Recognized: #{recognized.inspect}"

# 4. Simulate Request to /index/show/:id
puts "\n4. Simulating Request to /index/show/#{index_a.id}..."
path_show = url_helpers.index_show_path(index_a.id)
puts "Path: #{path_show}"
recognized_show = Rails.application.routes.recognize_path(path_show)
puts "Route Recognized: #{recognized_show.inspect}"

if recognized[:controller] == 'indices' && recognized[:action] == 'index' &&
   recognized_show[:controller] == 'indices' && recognized_show[:action] == 'show'
  puts "\n✅ Verification Passed: Routes and Data setup are correct."
  puts "Please visit http://localhost:3000/index/1 in your browser to confirm UI."
else
  puts "\n❌ Verification Failed: Routes not recognized correctly."
end

# frozen_string_literal: true

require_relative '../config/environment'

puts '== Starting Member Order Verification =='

# 1. Test Data Setup
wiki_content = <<~WIKI
  TestUnit(TestUnit)
  {{category Band}}
  {{member Vo, Member1, Member1}}
  {{member Gt, Member2, Member2}}
  {{member Ba, Member3, Member3}}
  {{member Dr, Member4, Member4}}
WIKI

wp = Wikipage.create!(name: "TestUnitOrder_#{Time.now.to_i}", title: 'TestUnitOrder', wiki: wiki_content)

# 2. Run Import
puts "\n[Importing Unit]"
WikipageImporter.import(wp)

# 3. Verify Order
puts "\n[Verifying UnitPerson Order]"
unit = Unit.find_by(old_wiki_id: wp.id)

if unit.nil?
  puts "FAIL: Unit 'TestUnit' not found!"
  puts "Units count: #{Unit.count}"
  puts "First Unit: #{Unit.first&.inspect}"
  exit 1
end

puts "Unit found: #{unit.name} (ID: #{unit.id})"
members = unit.unit_people.order(:order_in_period)

puts "UnitPerson count: #{members.count}"
if members.empty?
  puts 'FAIL: No members found for unit.'
  puts "All UnitPeople count: #{UnitPerson.count}"
  puts "Wiki Content:\n#{wp.wiki}"
  exit 1
end

members.each do |up|
  puts "  #{up.person_name}: order=#{up.order_in_period} (Expected: matches index)"
end

orders = members.map(&:order_in_period)
if orders == [1, 2, 3, 4]
  puts "\nPASS: Order is sequential (1, 2, 3, 4)"
else
  puts "\nFAIL: Order is NOT sequential. Got: #{orders.inspect}"
end

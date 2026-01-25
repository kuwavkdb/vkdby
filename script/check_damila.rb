# frozen_string_literal: true

class Wikipage < ActiveRecord::Base
end

wp = Wikipage.find(16_463)
puts '=== DAMILA Wikipage ==='
puts "ID: #{wp.id}"
puts "Name: #{wp.name}"
puts 'Wiki content:'
puts wp.wiki
puts
puts '=== Current UnitPerson records ==='
unit = Unit.find_by(old_key: 'DAMILA')
if unit
  puts "Unit ID: #{unit.id}"
  UnitPerson.where(unit_id: unit.id).each do |up|
    puts "  - #{up.person_name} (#{up.part})"
  end
else
  puts 'Unit not found'
end

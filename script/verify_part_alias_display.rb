# frozen_string_literal: true

require_relative '../config/environment'
require 'open-uri'

puts '== Verifying Part Alias Display =='

# 1. Find the latest test unit
unit = Unit.where('name LIKE ?', 'PartTestUnit%').order(created_at: :desc).first

unless unit
  puts 'ERROR: Test unit not found. Please run verify_part_improvements.rb first.'
  exit 1
end

puts "Checking Unit: #{unit.name} (Key: #{unit.key})"
url = "http://localhost:3000/#{unit.key}"

begin
  # Fetch page content
  # rubocop:disable Security/Open
  html = URI.open(url).read
  # rubocop:enable Security/Open

  puts "Fetched #{html.length} bytes."

  # 2. Check Member Rows
  # BangUnknown -> Alias: "UnknownPart", Support: false
  # Expected: <span ... title="UNKNOWN">UnknownPart</span>
  if html.match?(%r{title="UNKNOWN"[^>]*>\s*UnknownPart\s*</span>}m)
    puts 'OK: [BangUnknown] Displays alias "UnknownPart" with title "UNKNOWN"'
  else
    puts 'FAIL: [BangUnknown] Failed to find expected HTML for UnknownPart'
  end

  # BangSupportUnknown -> Alias: "Unknown", Support: true
  # Expected: <span ... title="UNKNOWN">サポート Unknown</span>
  if html.match?(%r{title="UNKNOWN"[^>]*>\s*サポート Unknown\s*</span>}m)
    puts 'OK: [BangSupportUnknown] Displays "サポート Unknown" with title "UNKNOWN"'
  else
    puts 'FAIL: [BangSupportUnknown] Failed to find expected HTML for "サポート Unknown"'
  end

  # BangVocal -> Alias: nil, Support: false
  # Expected: <span ... title="">VOCAL</span> (or no title if it was empty, actually my code puts empty string)
  # My code: title=""
  if html.match?(%r{title=""[^>]*>\s*VOCAL\s*</span>}m)
    puts 'OK: [BangVocal] Displays "VOCAL" with empty title'
  else
    puts 'FAIL: [BangVocal] Failed to find expected HTML for VOCAL'
    puts 'Debug: HTML content check:'
    puts "  Contains 'PartTestUnit'? #{html.include?('PartTestUnit')}"
    puts "  Contains 'BangVocal'? #{html.include?('BangVocal')}"
    puts "  Contains 'BangUnknown'? #{html.include?('BangUnknown')}"
    puts "  Contains 'UnknownPart'? #{html.include?('UnknownPart')}"

    # Dump member row HTML
    puts 'Debug: Member Row Snippets:'
    puts html.scan(%r{<div class="[^"]*member-row[^"]*".*?</div>}m) # Adjust regex if class logic is complex, or generic div match

    # Simple dump of relevant lines
    puts "Debug: Lines containing 'Bang':"
    html.each_line do |line|
      puts line.strip if line.include?('Bang')
    end

    # Dump lines around 'Bang'
    puts 'Debug: Context around BangVocal:'
    offset = html.index('BangVocal') || 0
    puts html[offset - 200..offset + 200]
  end
rescue StandardError => e
  puts "ERROR: Failed to fetch page: #{e.message}"
  puts 'Make sure rails server is running on port 3000.'
end

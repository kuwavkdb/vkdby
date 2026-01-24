namespace :db do
  desc "Import wikipages data from MySQL dump file"
  task import_wikipages_from_dump: :environment do
    puts "=== Starting Wikipages Import from MySQL Dump ==="
    
    dump_file = Rails.root.join("wikipages_all_20260114.sql")
    unless File.exist?(dump_file)
      puts "✗ Dump file not found: #{dump_file}"
      exit 1
    end
    
    puts "✓ Found dump file: #{dump_file}"
    
    # Define Wikipage model temporarily
    class Wikipage < ActiveRecord::Base
    end
    
    imported_count = 0
    errors = []
    
    puts "\n--- Parsing MySQL dump file ---"
    
    # Read and parse INSERT statements from MySQL dump
    File.open(dump_file, "r:UTF-8") do |file|
      current_insert = ""
      
      file.each_line do |line|
        # Look for INSERT INTO statements for wikipages table
        if line =~ /^INSERT INTO `wikipages`/
          current_insert = line
        elsif !current_insert.empty?
          current_insert += line
        end
        
        # Process when we have a complete INSERT statement (ends with ;)
        if current_insert =~ /;\s*$/
          # Extract values from INSERT statement
          # Format: INSERT INTO `wikipages` VALUES (id, name, wiki, ...),(id, name, wiki, ...),...;
          values_match = current_insert.match(/VALUES\s+(.+);/m)
          
          if values_match
            values_string = values_match[1]
            
            # Split by ),( to get individual records
            # This is a simplified parser - may need adjustment for complex data
            records = values_string.scan(/\(([^)]+(?:\([^)]*\)[^)]*)*)\)/)
            
            records.each do |record_match|
              begin
                # Parse the values (this is simplified and may need adjustment)
                values = record_match[0].split(/,(?=(?:[^']*'[^']*')*[^']*$)/)
                
                next if values.size < 13  # Skip if not enough columns
                
                # Clean up values (remove quotes, handle NULLs)
                clean_values = values.map do |v|
                  v = v.strip
                  if v == "NULL"
                    nil
                  elsif v.start_with?("'") && v.end_with?("'")
                    # Remove quotes and unescape
                    v[1..-2].gsub("\\'", "'").gsub("\\\\", "\\")
                  else
                    v
                  end
                end
                
                # Create Wikipage record
                Wikipage.create!(
                  id: clean_values[0],
                  name: clean_values[1],
                  wiki: clean_values[2],
                  updated_at: clean_values[3],
                  created_at: clean_values[4],
                  category: clean_values[5],
                  level: clean_values[6],
                  ip: clean_values[7],
                  dw_id: clean_values[8],
                  it_id: clean_values[9],
                  pia_id: clean_values[10],
                  eplus_id: clean_values[11],
                  title: clean_values[12]
                )
                
                imported_count += 1
                print "\rImported: #{imported_count}" if imported_count % 100 == 0
                
              rescue => e
                errors << { values: record_match[0][0..100], error: e.message }
              end
            end
          end
          
          current_insert = ""
        end
      end
    end
    
    puts "\n✓ Imported #{imported_count} records"
    
    # Reset sequence
    puts "\n--- Resetting PostgreSQL sequence ---"
    max_id = Wikipage.maximum(:id) || 0
    ActiveRecord::Base.connection.execute(
      "SELECT setval('wikipages_id_seq', #{max_id}, true)"
    )
    puts "✓ Reset wikipages_id_seq to #{max_id}"
    
    # Verify
    puts "\n--- Verification ---"
    pg_count = Wikipage.count
    puts "PostgreSQL count: #{pg_count}"
    
    if errors.any?
      puts "\n⚠ Errors encountered:"
      errors.first(5).each { |e| puts "  - #{e[:error]}" }
      puts "  ... and #{errors.size - 5} more" if errors.size > 5
    end
    
    puts "\n=== Import Complete ==="
  end
end

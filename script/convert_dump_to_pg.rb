# frozen_string_literal: true

input_file = 'wikipages_all_20260114.sql'
output_file = 'wikipages_recover_pg.sql'

File.open(output_file, 'w') do |out|
  # PostgreSQL settings for compatibility
  # PostGreSQL settings and table prep
  out.puts "SET standard_conforming_strings = off;"
  out.puts "SET escape_string_warning = off;"
  out.puts "ALTER TABLE wikipages ALTER COLUMN created_at DROP NOT NULL;"
  out.puts "TRUNCATE TABLE wikipages CASCADE;"

  in_insert = false
  File.foreach(input_file) do |line|
    if line.start_with?('INSERT INTO')
      in_insert = true
      # Remove backticks from the INSERT statement line
      out.puts line.gsub('`', '')
      
      # If the INSERT statement ends on the same line
      if line.strip.end_with?(';')
        in_insert = false
      end
    elsif in_insert
      # Convert MySQL zero date to epoch
      pg_line = line.gsub("'0000-00-00 00:00:00'", "'1970-01-01 00:00:00'")
      out.puts pg_line
      
      # Check for end of INSERT statement
      if line.strip.end_with?(';')
        in_insert = false
      end
    end
  end
  
  # Post-import cleanup
  out.puts "UPDATE wikipages SET created_at = updated_at WHERE created_at IS NULL;"
  out.puts "ALTER TABLE wikipages ALTER COLUMN created_at SET NOT NULL;"
  out.puts "SELECT setval('wikipages_id_seq', (SELECT MAX(id) FROM wikipages));"
end

puts "Converted #{input_file} to #{output_file}"

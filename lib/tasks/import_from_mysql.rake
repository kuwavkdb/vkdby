namespace :db do
  desc "Import all wikipages data directly from MySQL server"
  task import_from_mysql: :environment do
    # This task requires mysql2 gem temporarily
    # Run: gem install mysql2 (without adding to Gemfile)

    begin
      require "mysql2"
    rescue LoadError
      puts "✗ mysql2 gem is required for this task"
      puts "Run: gem install mysql2"
      exit 1
    end

    puts "=== Starting Direct MySQL to PostgreSQL Migration ==="

    # MySQL connection configuration
    mysql_config = {
      host: ENV.fetch("MYSQL_HOST", "127.0.0.1"),
      username: ENV.fetch("MYSQL_USER", "root"),
      password: ENV.fetch("MYSQL_PASSWORD", ""),
      database: "vkdby_development"
    }

    begin
      mysql_client = Mysql2::Client.new(mysql_config)
      puts "✓ Connected to MySQL database"

      # Get wikipages count from MySQL
      result = mysql_client.query("SELECT COUNT(*) as count FROM wikipages")
      mysql_count = result.first["count"]
      puts "✓ Found #{mysql_count} records in MySQL wikipages table"

      # Define Wikipage model temporarily
      class Wikipage < ActiveRecord::Base
      end

      # Clear existing data
      puts "\n--- Clearing existing PostgreSQL data ---"
      existing_count = Wikipage.count
      if existing_count > 0
        print "Found #{existing_count} existing records. Delete them? (y/N): "
        response = STDIN.gets.chomp
        if response.downcase == "y"
          Wikipage.delete_all
          puts "✓ Deleted #{existing_count} records"
        else
          puts "Keeping existing records. Will skip duplicates."
        end
      end

      # Fetch all wikipages from MySQL
      puts "\n--- Fetching wikipages from MySQL ---"
      wikipages_data = mysql_client.query("SELECT * FROM wikipages ORDER BY id", as: :hash)

      # Import into PostgreSQL
      puts "\n--- Importing into PostgreSQL ---"
      imported_count = 0
      skipped_count = 0
      errors = []

      wikipages_data.each_with_index do |row, index|
        begin
          # Check if record already exists
          if Wikipage.exists?(id: row["id"])
            skipped_count += 1
            next
          end

          Wikipage.create!(
            id: row["id"],
            name: row["name"],
            title: row["title"],
            wiki: row["wiki"],
            category: row["category"],
            level: row["level"],
            ip: row["ip"],
            dw_id: row["dw_id"],
            it_id: row["it_id"],
            pia_id: row["pia_id"],
            eplus_id: row["eplus_id"],
            created_at: row["created_at"],
            updated_at: row["updated_at"]
          )

          imported_count += 1
          print "\rImported: #{imported_count}/#{mysql_count} (Skipped: #{skipped_count})" if (index + 1) % 100 == 0
        rescue => e
          errors << { id: row["id"], name: row["name"], error: e.message }
        end
      end

      puts "\n✓ Imported #{imported_count} records successfully"
      puts "✓ Skipped #{skipped_count} existing records" if skipped_count > 0

      # Reset sequence for wikipages id
      puts "\n--- Resetting PostgreSQL sequence ---"
      max_id = Wikipage.maximum(:id) || 0
      ActiveRecord::Base.connection.execute(
        "SELECT setval('wikipages_id_seq', #{max_id}, true)"
      )
      puts "✓ Reset wikipages_id_seq to #{max_id}"

      # Verify data
      puts "\n--- Verifying data integrity ---"
      pg_count = Wikipage.count
      puts "PostgreSQL count: #{pg_count}"
      puts "MySQL count: #{mysql_count}"

      if pg_count == mysql_count
        puts "✓ Data migration completed successfully!"
      else
        puts "⚠ Warning: Record count mismatch"
        puts "  PostgreSQL: #{pg_count}"
        puts "  MySQL: #{mysql_count}"
        puts "  Difference: #{mysql_count - pg_count}"
      end

      if errors.any?
        puts "\n⚠ Errors encountered during migration:"
        errors.first(10).each do |error|
          puts "  - ID #{error[:id]} (#{error[:name]}): #{error[:error]}"
        end
        puts "  ... and #{errors.size - 10} more errors" if errors.size > 10
      end

    rescue Mysql2::Error => e
      puts "✗ MySQL connection error: #{e.message}"
      puts "Make sure MySQL is running and the database exists."
      exit 1
    ensure
      mysql_client&.close
    end

    puts "\n=== Migration Complete ==="
  end
end

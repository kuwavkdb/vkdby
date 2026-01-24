namespace :db do
  desc "Import users data from MySQL to PostgreSQL"
  task import_users_from_mysql: :environment do
    begin
      require "mysql2"
    rescue LoadError
      puts "✗ mysql2 gem is required for this task"
      puts "Run: gem install mysql2"
      exit 1
    end

    puts "=== Starting Users Data Migration from MySQL to PostgreSQL ==="

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

      # Get users count from MySQL
      result = mysql_client.query("SELECT COUNT(*) as count FROM users")
      mysql_count = result.first["count"]
      puts "✓ Found #{mysql_count} records in MySQL users table"

      # Clear existing data
      puts "\n--- Clearing existing PostgreSQL users data ---"
      existing_count = User.count
      if existing_count > 0
        print "Found #{existing_count} existing users. Delete them? (y/N): "
        response = STDIN.gets.chomp
        if response.downcase == "y"
          User.delete_all
          puts "✓ Deleted #{existing_count} users"
        else
          puts "Keeping existing users. Will skip duplicates."
        end
      end

      # Fetch all users from MySQL
      puts "\n--- Fetching users from MySQL ---"
      users_data = mysql_client.query("SELECT * FROM users ORDER BY id", as: :hash)

      # Import into PostgreSQL
      puts "\n--- Importing into PostgreSQL ---"
      imported_count = 0
      skipped_count = 0
      errors = []

      users_data.each do |row|
        begin
          # Check if user already exists
          if User.exists?(id: row["id"])
            skipped_count += 1
            next
          end

          User.create!(
            id: row["id"],
            email: row["email"],
            name: row["name"],
            role: row["role"],
            password_digest: row["password_digest"],
            created_at: row["created_at"],
            updated_at: row["updated_at"]
          )

          imported_count += 1
          puts "  ✓ Imported user: #{row['email']} (ID: #{row['id']})"
        rescue => e
          errors << { id: row["id"], email: row["email"], error: e.message }
        end
      end

      puts "\n✓ Imported #{imported_count} users successfully"
      puts "✓ Skipped #{skipped_count} existing users" if skipped_count > 0

      # Reset sequence for users id
      puts "\n--- Resetting PostgreSQL sequence ---"
      max_id = User.maximum(:id) || 0
      ActiveRecord::Base.connection.execute(
        "SELECT setval('users_id_seq', #{max_id}, true)"
      )
      puts "✓ Reset users_id_seq to #{max_id}"

      # Verify data
      puts "\n--- Verifying data integrity ---"
      pg_count = User.count
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
        errors.each do |error|
          puts "  - ID #{error[:id]} (#{error[:email]}): #{error[:error]}"
        end
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

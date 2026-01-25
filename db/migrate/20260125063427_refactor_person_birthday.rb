class RefactorPersonBirthday < ActiveRecord::Migration[8.1]
  def up
    # Add birth_year column
    add_column :people, :birth_year, :integer

    # Migrate existing data
    Person.reset_column_information
    Person.find_each do |person|
      next unless person.birthday

      # If birth_year_unknown is false, save the year to birth_year
      unless person.birth_year_unknown
        person.update_column(:birth_year, person.birthday.year)
      end

      # Normalize birthday year to 1904
      normalized_birthday = person.birthday.change(year: 1904)
      person.update_column(:birthday, normalized_birthday)
    end

    # Remove birth_year_unknown column
    remove_column :people, :birth_year_unknown, :boolean
  end

  def down
    # Add back birth_year_unknown column
    add_column :people, :birth_year_unknown, :boolean

    # Restore data
    Person.reset_column_information
    Person.find_each do |person|
      next unless person.birthday

      # Set birth_year_unknown based on birth_year presence
      person.update_column(:birth_year_unknown, person.birth_year.nil?)

      # Restore birthday year from birth_year if available
      if person.birth_year
        restored_birthday = person.birthday.change(year: person.birth_year)
        person.update_column(:birthday, restored_birthday)
      end
    end

    # Remove birth_year column
    remove_column :people, :birth_year, :integer
  end
end

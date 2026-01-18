class AddBirthYearUnknownToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :birth_year_unknown, :boolean
  end
end

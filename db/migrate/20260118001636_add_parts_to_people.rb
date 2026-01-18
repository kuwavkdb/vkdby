class AddPartsToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :parts, :json
  end
end

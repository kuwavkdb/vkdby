class AddNameAliasToSnapshotPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :snapshot_people, :name_alias, :string
  end
end

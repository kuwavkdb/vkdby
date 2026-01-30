class AddOldWikiIdToPeopleAndUnits < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :old_wiki_id, :integer
    add_column :units, :old_wiki_id, :integer
  end
end

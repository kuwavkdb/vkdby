class AddOldWikiTextToUnitsAndPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :units, :old_wiki_text, :text
    add_column :people, :old_wiki_text, :text
  end
end

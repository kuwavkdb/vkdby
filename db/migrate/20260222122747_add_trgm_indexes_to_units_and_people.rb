# frozen_string_literal: true

class AddTrgmIndexesToUnitsAndPeople < ActiveRecord::Migration[8.0]
  def up
    remove_index :units, :name
    remove_index :units, :name_kana
    remove_index :people, :name
    remove_index :people, :name_kana

    add_index :units, :name, using: :gin, opclass: :gin_trgm_ops
    add_index :units, :name_kana, using: :gin, opclass: :gin_trgm_ops
    add_index :people, :name, using: :gin, opclass: :gin_trgm_ops
    add_index :people, :name_kana, using: :gin, opclass: :gin_trgm_ops
  end

  def down
    remove_index :units, :name
    remove_index :units, :name_kana
    remove_index :people, :name
    remove_index :people, :name_kana

    add_index :units, :name
    add_index :units, :name_kana
    add_index :people, :name
    add_index :people, :name_kana
  end
end

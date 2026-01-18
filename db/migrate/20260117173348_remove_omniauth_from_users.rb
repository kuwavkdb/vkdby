class RemoveOmniauthFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :uid, :string
    remove_column :users, :provider, :string
  end
end

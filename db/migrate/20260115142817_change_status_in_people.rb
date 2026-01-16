class ChangeStatusInPeople < ActiveRecord::Migration[8.1]
  def change
    # 既存の NULL レコードをデフォルト値 1 に更新
    say "Updating existing NULL status to 1..."
    Person.where(status: nil).update_all(status: 1)
    
    change_column :people, :status, :integer, null: false, default: 1
  end
end

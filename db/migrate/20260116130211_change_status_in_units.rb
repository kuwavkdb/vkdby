class ChangeStatusInUnits < ActiveRecord::Migration[8.1]
  def up
    # 既存の nil を 1 (active) に更新
    Unit.where(status: nil).update_all(status: 1)
    
    change_column_null :units, :status, false
    change_column_default :units, :status, from: nil, to: 1
  end

  def down
    change_column_default :units, :status, from: 1, to: nil
    change_column_null :units, :status, true
  end
end

class ChangeUnitPeopleStatusToNotNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :unit_people, :status, false
    change_column_default :unit_people, :status, from: nil, to: 1 # 1 is active
  end
end

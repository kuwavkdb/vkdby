class AddSnapshotDateToTrends < ActiveRecord::Migration[8.1]
  def change
    add_column :trends, :snapshot_date, :date
  end
end

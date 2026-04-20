class AddUsageToIndexGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :index_groups, :units_filter_order, :integer, default: nil
    add_column :index_groups, :people_filter_order, :integer, default: nil

    # 既存データの初期値を現状の運用に合わせて設定
    # id:1 (カナ索引) -> Units用 表示順1, id:2 (個人カナ索引) -> People用 表示順1
    reversible do |dir|
      dir.up do
        execute "UPDATE index_groups SET units_filter_order = 1 WHERE id = 1"
        execute "UPDATE index_groups SET people_filter_order = 1 WHERE id = 2"
      end
    end
  end
end

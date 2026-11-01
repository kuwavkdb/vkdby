# frozen_string_literal: true

# ステータス「移行」（transitioned。別ユニットとして活動を継続）のユニットの後継ユニット（issue #1996）。
# 後継ユニットが消えたら、移行したユニット側の参照だけを外す
class AddTransitionedUnitToUnits < ActiveRecord::Migration[8.1]
  def change
    add_reference :units, :transitioned_unit, null: true, index: true,
                                              foreign_key: { to_table: :units, on_delete: :nullify }
  end
end

# frozen_string_literal: true

# UpdateLogに「どのレコードが編集されたか」(loggable)とは別に、「その編集をどの
# ページ（Unit/Person/CustomPage）の更新として扱うか」(subject)を持たせる（issue #1530）。
# Link/Section/UnitSnapshot/SnapshotPersonのようなネストしたレコードの編集も、
# 書き込み時に親ページをsubjectとして記録しておくことで、サイドバー「最近の更新」を
# UpdateLogから安価に（実行時の逆引きなしで）集計できるようにする。
class AddSubjectToUpdateLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :update_logs, :subject_type, :string
    add_column :update_logs, :subject_id, :bigint
    add_index :update_logs, %i[subject_type subject_id]
    add_index :update_logs, %i[subject_type created_at]
  end
end

# frozen_string_literal: true

class AddExtraProfileToSnapshotPeople < ActiveRecord::Migration[8.1]
  def change
    # Person に未紐付けのメンバーの下書きプロフィール情報（誕生日・生年・血液型・出身地）を
    # 保持するためのカラム（issue #1619）。Person側の正式カラムと異なり、月日のみ・年不明などの
    # 不完全な情報でも自由な形で入れられるよう jsonb にする。
    add_column :snapshot_people, :extra_profile, :jsonb
  end
end

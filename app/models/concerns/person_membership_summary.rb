# frozen_string_literal: true

# 個人の今の在籍ユニット。
# 構造化データ（JsonLdHelper#person_json_ld）とmeta description（MetaDescriptionHelper）で
# 同じ結果を使うためのもの（issue #1938）。過去の在籍バンドは meta description で個人の経歴から組み立てる（issue #1945）
module PersonMembershipSummary
  extend ActiveSupport::Concern

  # 今在籍しているユニット（「現在」のスナップショットの在籍メンバー。サポート・関係者は除く）。
  # 解散したユニットは「現在」のスナップショットが残っていても含めない。
  # 引退した人は、「現在」のスナップショットに在籍として残っていても今の所属は無いものとする
  # 死去した人は最後に在籍したユニットをそのまま返す。
  # 「他」で切ったときに載るユニットが表示のたびに入れ替わらないよう、ユニットの id 順にする
  def current_units
    return [] if retirement?

    membership_snapshot_people.where(status: :active)
                              .where(unit_snapshots: { current: true })
                              .where(unit_snapshots: { unit_id: Unit.where.not(status: :disbanded).select(:id) })
                              .order('unit_snapshots.unit_id')
                              .includes(unit_snapshot: :unit)
                              .map { |member| member.unit_snapshot.unit }
                              .uniq
  end

  private

  # 所属を求めるもとになる、この個人のスナップショット上の載り方（サポート・関係者スナップショット・
  # 非表示のスナップショットを除く）。非公開のユニットと、キー変更・統合で転送しているユニットも除く
  def membership_snapshot_people
    SnapshotPerson.where(person_id: id, support: false)
                  .joins(:unit_snapshot)
                  .where(unit_snapshots: { past: false, active: true,
                                           unit_id: Unit.for_index.published.where(destination_key: [nil, '']).select(:id) })
  end
end

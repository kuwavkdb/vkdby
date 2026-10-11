# frozen_string_literal: true

# 個人ページのないメンバー（SnapshotPerson.unlinked_matching の結果）を、個人の検索結果に
# 個人カードと同じ見た目で出す（issue #1843）。個人ページはないため、所属ユニットのページの
# そのスナップショットを開いた状態（#snapshot-{id}、issue #1761）へリンクする。
# 見た目の部品（配色・フォーカス表示など）は PersonCardComponent のものを使う。
class UnlinkedMemberCardComponent < PersonCardComponent
  with_collection_parameter :member

  def initialize(member:)
    super(person: member)
    @member = member
  end

  private

  def unit
    @member.unit_snapshot.unit
  end

  def path
    helpers.profile_path(unit.key, anchor: "snapshot-#{@member.unit_snapshot_id}")
  end

  def role_label
    @member.unit_snapshot.past? ? '関係者' : 'メンバー'
  end

  # メンバー一覧（MemberRowComponent）と同じ表記。パート不明で別名もなければ出さない
  def part_text
    return if @member.part_alias.blank? && @member.unknown?

    (@member.support? ? 'サポート ' : '') + (@member.part_alias.presence || @member.part.upcase)
  end
end

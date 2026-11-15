# frozen_string_literal: true

# 人物に紐づいた SnapshotPerson の person_name に、旧wikiでの在籍時の表示名を入れる（issue #1972）。
#
# 2026-03-31（91c0cb4）より前の取り込みでは、人物が見つかった行の person_name を保存しておらず、
# SnapshotPerson#name が個人の現在の名前を表示していた。本番には wikipages が無いため、
# ローカルで script/export_wiki_member_names.rb が書き出した TSV を読み、本番で反映する。
#
# 新サイトで手を入れた行を上書きしないよう、次をすべて満たす行だけを更新する。
# - person_name が空のまま
# - person_id と old_person_key が書き出し時と同じ
# - 紐付け先 Person の名前が書き出し時と同じ
class SnapshotPersonNameBackfill
  HEADERS = %w[snapshot_person_id person_id old_person_key current_person_name wiki_name kind].freeze

  SKIP_REASONS = {
    not_found: 'SnapshotPerson が見つからない',
    blank_wiki_name: '旧wikiの表示名が空',
    person_name_present: 'person_name が入力済み',
    person_changed: '紐付け先の個人が変わっている',
    old_person_key_changed: 'old_person_key が変わっている',
    person_renamed: '個人の名前が書き出し時から変わっている',
    same_as_person_name: '個人の名前と同じ'
  }.freeze

  Result = Struct.new(:row, :status, :reason, :snapshot_person, keyword_init: true) do
    def skipped?
      status == :skipped
    end
  end

  # TSV（1行目は HEADERS）を読み、各行を HEADERS をキーにした Hash にする
  def self.read_tsv(path)
    lines = File.readlines(path, chomp: true, encoding: 'UTF-8')
    headers = lines.shift.to_s.split("\t")
    missing = HEADERS - headers
    raise ArgumentError, "TSVの列が足りません: #{missing.join(', ')}" if missing.any?

    lines.compact_blank.map { |line| headers.zip(line.split("\t", -1)).to_h }
  end

  def initialize(rows, apply: false)
    @rows = rows
    @apply = apply
  end

  def call
    snapshot_people = SnapshotPerson.with_discarded.includes(:person)
                                    .where(id: @rows.map { |row| row['snapshot_person_id'] })
                                    .index_by(&:id)

    @rows.map do |row|
      snapshot_person = snapshot_people[row['snapshot_person_id'].to_i]
      reason = skip_reason(row, snapshot_person)
      next Result.new(row:, status: :skipped, reason:, snapshot_person:) if reason

      # save! で belongs_to :unit_snapshot, touch: true を働かせ、{{snapshot}} のキャッシュを無効化する。
      # person_id は変えないため、merge_sns_into_person は動かない。
      snapshot_person.update!(person_name: row['wiki_name']) if @apply
      Result.new(row:, status: @apply ? :updated : :would_update, snapshot_person:)
    end
  end

  private

  def skip_reason(row, snapshot_person)
    return :not_found if snapshot_person.nil?
    return :blank_wiki_name if row['wiki_name'].blank?
    return :person_name_present if snapshot_person.person_name.present?
    return :person_changed if snapshot_person.person_id.to_s != row['person_id'].to_s
    return :old_person_key_changed if snapshot_person.old_person_key.to_s != row['old_person_key'].to_s
    return :person_renamed if snapshot_person.person&.name.to_s != row['current_person_name'].to_s

    :same_as_person_name if row['wiki_name'] == snapshot_person.person.name
  end
end

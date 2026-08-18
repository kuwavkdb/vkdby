# frozen_string_literal: true

namespace :temporary_snapshot_people do
  desc '既存のギャップ一覧（tmp/unit_people_snapshot_gap.tsv）を temporary_snapshot_people に取り込む（ローカル調査・移行用）'
  task backfill_from_gap_tsv: :environment do
    tsv_path = Rails.root.join('tmp', 'unit_people_snapshot_gap.tsv')
    abort "エラー: #{tsv_path} が見つかりません（ローカルにのみ存在する調査用ファイルです）" unless File.exist?(tsv_path)

    lines = File.readlines(tsv_path, chomp: true)
    headers = lines.shift.split("\t")

    created = 0
    already_pooled = 0
    not_found = []

    lines.each do |line|
      next if line.blank?

      row = headers.zip(line.split("\t")).to_h
      unit = Unit.kept.find_by(key: row['unit_key'])
      person = Person.kept.find_by(key: row['person_key'])

      unit_person = (UnitPerson.find_by(unit: unit, person: person, status: row['status']) if unit && person)
      unit_person ||= (UnitPerson.find_by(unit: unit, person_key: row['person_key'], status: row['status']) if unit)

      if unit.nil? || unit_person.nil?
        not_found << "#{row['person_name']}（#{row['person_key']}） / #{row['unit_name']}（#{row['unit_key']}）"
        next
      end

      if TemporarySnapshotPerson.where(hint_unit_id: unit.id)
                                .where(person_id: unit_person.person_id, person_key: unit_person.person_key)
                                .exists?
        already_pooled += 1
        next
      end

      TemporarySnapshotPerson.create!(
        person_id: unit_person.person_id,
        person_key: unit_person.person_key,
        person_name: unit_person.person_name,
        part: unit_person.part,
        part_alias: unit_person.part_alias,
        support: unit_person.support,
        status: unit_person.status,
        old_person_key: unit_person.old_person_key,
        sns: unit_person.sns,
        inline_history: unit_person.inline_history,
        hint_unit_id: unit.id,
        source: 'unit_people_gap_backfill'
      )
      created += 1
    end

    puts "取り込み完了: #{created}件作成 / #{already_pooled}件は既にプール済みのためスキップ"
    if not_found.any?
      puts "対応するUnitPersonが見つからなかった行: #{not_found.size}件"
      not_found.each { |line| puts "  - #{line}" }
    end
  end
end

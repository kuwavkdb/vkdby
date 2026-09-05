# frozen_string_literal: true

namespace :snapshot_people do
  desc 'person_nameが空でname_aliasのみ入っているSnapshotPersonをperson_nameに寄せる（issue #1361）'
  task migrate_name_alias_to_person_name: :environment do
    dry_run = ENV['DRY_RUN'].present?

    scope = SnapshotPerson.with_discarded
                          .where(person_name: [nil, ''])
                          .where.not(name_alias: [nil, ''])
    total = scope.count
    puts "対象: #{total}件#{dry_run ? ' (DRY RUN)' : ''}"

    scope.find_each do |snapshot_person|
      puts "- ##{snapshot_person.id} unit_snapshot_id=#{snapshot_person.unit_snapshot_id} " \
           "person_id=#{snapshot_person.person_id} name_alias=#{snapshot_person.name_alias.inspect}"
      # nameの解決結果（表示）を変えないための単純コピーであり、バリデーション/コールバックは不要なため
      # update_columnを使用
      snapshot_person.update_column(:person_name, snapshot_person.name_alias) unless dry_run
    end

    puts "\n完了。#{dry_run ? '対象' : '更新'}: #{total}件"
  end
end

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

  desc '紐付け済みSnapshotPersonのsnsを、紐付け先PersonのLinkにマージする（issue #1654）。既定はdry-run、APPLY=1で実行'
  task merge_sns_into_people: :environment do
    apply = ENV['APPLY'] == '1'
    puts apply ? '== APPLY: Linkを追加します ==' : '== DRY RUN: 追加予定のLinkを表示します（実行するには APPLY=1） =='

    # dry-runでは保存しないため、同じPersonに紐付く複数のSnapshotPersonの間での重複をここで判定する
    planned_urls = Hash.new { |hash, key| hash[key] = [] }
    total = 0

    SnapshotPerson.includes(:person).where.not(person_id: nil).where.not(sns: nil).find_each do |snapshot_person|
      person = snapshot_person.person
      next if person.nil?

      urls = if apply
               snapshot_person.merge_sns_into_person.map(&:url)
             else
               snapshot_person.sns_urls_missing_from(person, known_urls: planned_urls[person.id])
             end
      next if urls.empty?

      planned_urls[person.id].concat(urls)
      total += urls.size
      urls.each do |url|
        puts "- Person ##{person.id} #{person.name}（SnapshotPerson ##{snapshot_person.id}）: #{url}"
      end
    end

    puts "\n完了。#{apply ? '追加' : '追加予定'}: #{total}件"
  end
end

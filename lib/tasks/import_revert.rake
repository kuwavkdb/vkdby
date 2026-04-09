# frozen_string_literal: true

# インポートデータの修正用ワンショットタスク集
# wiki_page_imports を更新してから Unit を削除する共通パターン

def revert_units(unit_ids, page_type:)
  dry_run = ENV['DRY_RUN'] != 'false'
  puts dry_run ? 'Mode: DRY RUN (実際には変更しません。DRY_RUN=false で本実行)' : 'Mode: 本実行'
  puts

  updated = 0
  deleted = 0
  errors  = 0

  ActiveRecord::Base.transaction do
    unit_ids.each do |unit_id|
      unit = Unit.find_by(id: unit_id)
      unless unit
        puts "[SKIP] Unit##{unit_id}: not found"
        next
      end

      wpi = WikiPageImport.find_by(import_target: unit)
      unless wpi
        puts "[WARN] Unit##{unit_id} (#{unit.name}): wiki_page_import not found"
        errors += 1
        next
      end

      sections_count  = unit.sections.count
      tag_items_count = TagIndexItem.where(indexable: unit).count

      puts "[TARGET] Unit##{unit_id} (#{unit.name}) wpi##{wpi.id} " \
           "sections=#{sections_count} tag_items=#{tag_items_count}"

      unless dry_run
        # 1. wiki_page_imports を先に更新（削除前に意図を記録）
        wpi.update!(status: 'skipped', page_type: page_type, manually_set: true)
        updated += 1

        # 2. 関連データを削除してから Unit を削除
        unit.sections.destroy_all
        TagIndexItem.where(indexable: unit).destroy_all
        unit.destroy!
        deleted += 1

        puts "  -> updated wpi##{wpi.id}, deleted Unit##{unit_id}"
      end
    rescue StandardError => e
      puts "[ERROR] Unit##{unit_id}: #{e.message}"
      errors += 1
      raise ActiveRecord::Rollback unless dry_run
    end

    raise ActiveRecord::Rollback if dry_run
  end

  puts
  puts dry_run ? 'Dry run complete!' : 'Revert complete!'
  puts "  Updated wiki_page_imports: #{updated}"
  puts "  Deleted Units:             #{deleted}"
  puts "  Errors:                    #{errors}" if errors.positive?
end

namespace :import do
  desc 'Revert Units that are actually person pages (issue #555 pattern1): update wiki_page_imports then delete Units'
  task revert_person_units: :environment do
    # unit_people=0 かつ unit_snapshots=0 で {{category 個人 を含む Unit（48件）
    person_unit_ids = [
      56, 64, 79, 266, 317, 318, 335, 336, 337, 339, 349, 350, 351, 358, 370, 372, 374, 388,
      414, 437, 440, 443, 452, 468, 471, 480, 519, 882, 922, 982, 1001, 1174, 1202, 1388, 1440,
      1452, 1565, 1578, 1603, 1604, 1646, 1713, 1774, 1801, 1899, 2032, 2397, 2426
    ].freeze

    revert_units(person_unit_ids, page_type: 'person')
  end

  desc 'Revert Units that are actually redirect/moved pages (issue #558): update wiki_page_imports then delete Units'
  task revert_moved_units: :environment do
    # リダイレクト・移動ページが Unit としてインポートされた93件
    moved_unit_ids = [
      3119, 3164, 3167, 3170, 3171, 3174, 3185, 3331, 3332, 3333, 3336, 3337, 3338, 3342, 3343,
      3344, 3346, 3347, 3358, 3359, 3364, 3367, 3369, 3373, 3378, 3379, 3382, 3386, 3393, 3395,
      3401, 3402, 3403, 3407, 3410, 3423, 3427, 3430, 3431, 3434, 3444, 3456, 3467, 3470, 3479,
      3490, 3503, 3513, 3530, 3539, 3542, 3550, 3562, 3574, 3578, 3583, 3590, 3591, 3596, 3636,
      3637, 3640, 3655, 3656, 3657, 3662, 3663, 3665, 3677, 3678, 3683, 3691, 3709, 3710, 3716,
      3717, 3731, 3736, 3739, 3746, 3753, 3756, 3765, 3767, 3773, 3776, 3794, 3796, 3802, 3805,
      3806, 3812, 3813
    ].freeze

    revert_units(moved_unit_ids, page_type: 'moved')
  end
end

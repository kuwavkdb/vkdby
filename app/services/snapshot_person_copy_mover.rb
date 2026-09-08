# frozen_string_literal: true

# SnapshotPerson を同ユニット内の別の UnitSnapshot へ複製する。
# mode: 'move' の場合は複製後に元のレコードを discard する。
class SnapshotPersonCopyMover
  def initialize(snapshot_people, target_snapshot, mode)
    @snapshot_people = snapshot_people
    @target_snapshot = target_snapshot
    @mode = mode == 'move' ? 'move' : 'copy'
  end

  # ブロックには複製・discardされたレコードと action('create'/'discard') が渡される
  def call
    base_sort_order = @target_snapshot.snapshot_people.maximum(:sort_order).to_i

    ActiveRecord::Base.transaction do
      @snapshot_people.each_with_index do |sp, index|
        new_sp = duplicate(sp, base_sort_order + index + 1)
        yield(new_sp, 'create')

        next unless @mode == 'move'

        sp.discard
        yield(sp, 'discard')
      end
    end
  end

  private

  def duplicate(snapshot_person, sort_order)
    attributes = snapshot_person.attributes.except('id', 'unit_snapshot_id', 'created_at', 'updated_at', 'sort_order')
    @target_snapshot.snapshot_people.create!(attributes.merge('sort_order' => sort_order))
  end
end

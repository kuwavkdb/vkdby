# frozen_string_literal: true

require 'test_helper'

# issue #1972: 紐付け済みSnapshotPersonのperson_nameに旧wikiでの在籍時の表示名を入れる
class SnapshotPersonNameBackfillTest < ActiveSupport::TestCase
  setup do
    @snapshot_person = snapshot_people(:one)
    @snapshot_person.update_columns(person_name: nil, old_person_key: 'MaSa')
    @person = @snapshot_person.person
  end

  def row(**overrides)
    {
      'snapshot_person_id' => @snapshot_person.id.to_s,
      'person_id' => @person.id.to_s,
      'old_person_key' => 'MaSa',
      'current_person_name' => @person.name,
      'wiki_name' => 'MaSa',
      'kind' => 'renamed'
    }.merge(overrides.transform_keys(&:to_s))
  end

  test 'dry-run does not change person_name' do
    result = SnapshotPersonNameBackfill.new([row]).call.first

    assert_equal :would_update, result.status
    assert_nil @snapshot_person.reload.person_name
  end

  test 'apply sets person_name and the display name' do
    result = SnapshotPersonNameBackfill.new([row], apply: true).call.first

    assert_equal :updated, result.status
    assert_equal 'MaSa', @snapshot_person.reload.person_name
    assert_equal 'MaSa', @snapshot_person.name
  end

  test 'apply touches the unit snapshot to expire the snapshot cache' do
    snapshot = @snapshot_person.unit_snapshot
    snapshot.update_columns(updated_at: 1.day.ago)

    assert_changes -> { snapshot.reload.updated_at } do
      SnapshotPersonNameBackfill.new([row], apply: true).call
    end
  end

  test 'skips a row whose person_name was already set on the new site' do
    @snapshot_person.update_columns(person_name: '手入力の名前')

    result = SnapshotPersonNameBackfill.new([row], apply: true).call.first

    assert_equal :person_name_present, result.reason
    assert_equal '手入力の名前', @snapshot_person.reload.person_name
  end

  test 'skips a row linked to another person since the export' do
    result = SnapshotPersonNameBackfill.new([row(person_id: people(:two).id)], apply: true).call.first

    assert_equal :person_changed, result.reason
    assert_nil @snapshot_person.reload.person_name
  end

  test 'skips a row whose old_person_key changed since the export' do
    result = SnapshotPersonNameBackfill.new([row(old_person_key: 'other')], apply: true).call.first

    assert_equal :old_person_key_changed, result.reason
  end

  test 'skips a row whose person was renamed since the export' do
    result = SnapshotPersonNameBackfill.new([row(current_person_name: '以前の名前')], apply: true).call.first

    assert_equal :person_renamed, result.reason
    assert_nil @snapshot_person.reload.person_name
  end

  test 'skips missing rows, blank names and names equal to the person name' do
    results = SnapshotPersonNameBackfill.new(
      [row(snapshot_person_id: 0), row(wiki_name: ''), row(wiki_name: @person.name)], apply: true
    ).call

    assert_equal %i[not_found blank_wiki_name same_as_person_name], results.map(&:reason)
  end

  test 'read_tsv parses rows by header' do
    Tempfile.create(['names', '.tsv']) do |file|
      file.puts SnapshotPersonNameBackfill::HEADERS.join("\t")
      file.puts [1, 2, 'MaSa', '聖月', 'MaSa', 'renamed'].join("\t")
      file.flush

      rows = SnapshotPersonNameBackfill.read_tsv(file.path)

      assert_equal [{ 'snapshot_person_id' => '1', 'person_id' => '2', 'old_person_key' => 'MaSa',
                      'current_person_name' => '聖月', 'wiki_name' => 'MaSa', 'kind' => 'renamed' }], rows
    end
  end

  test 'read_tsv keeps the reference columns for visual checks' do
    Tempfile.create(['names', '.tsv']) do |file|
      headers = SnapshotPersonNameBackfill::HEADERS + SnapshotPersonNameBackfill::REFERENCE_HEADERS
      file.puts headers.join("\t")
      file.puts [1, 2, 'MaSa', '聖月', 'MaSa', 'renamed', 'index', 'Distray', '結成時'].join("\t")
      file.flush

      row = SnapshotPersonNameBackfill.read_tsv(file.path).first

      assert_equal %w[index Distray 結成時], row.values_at('matched_by', 'unit_name', 'snapshot_label')
    end
  end

  test 'read_tsv raises when a column is missing' do
    Tempfile.create(['names', '.tsv']) do |file|
      file.puts %w[snapshot_person_id wiki_name].join("\t")
      file.flush

      assert_raises(ArgumentError) { SnapshotPersonNameBackfill.read_tsv(file.path) }
    end
  end
end

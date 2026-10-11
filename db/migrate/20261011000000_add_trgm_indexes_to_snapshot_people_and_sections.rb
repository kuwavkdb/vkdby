# frozen_string_literal: true

# 個人ページのないメンバー（snapshot_people）を個人の検索結果に出す（issue #1843）ために、
# person_name / name_alias / extra_profile の name_kana（ヨミガナの下書き）/ sections.name の
# 部分一致（ILIKE）を trigram index で引けるようにする。OR で並べた条件のうち1つでも index が
# なければ全件走査になるため、検索対象の列すべてに張る。
# sections.name には手作業で作った index（index_sections_on_name）が環境によって存在しうる。
# 同じ列に gin_trgm_ops の index が既にあれば、作り直さずに名前だけ付け替えて、どの環境でも
# schema.rb の index 名がそろうようにする。
class AddTrgmIndexesToSnapshotPeopleAndSections < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEXES = [
    [:snapshot_people, :person_name, 'index_snapshot_people_on_person_name_trgm'],
    [:snapshot_people, :name_alias, 'index_snapshot_people_on_name_alias_trgm'],
    [:sections, :name, 'index_sections_on_name_trgm']
  ].freeze
  NAME_KANA_INDEX = 'index_snapshot_people_on_extra_profile_name_kana_trgm'

  def up
    INDEXES.each do |table, column, name|
      existing = existing_trgm_index_name(table, column)
      if existing.nil?
        add_index table, column, using: :gin, opclass: :gin_trgm_ops, name:, algorithm: :concurrently
      elsif existing != name
        rename_index table, existing, name
      end
    end

    return if index_exists?(:snapshot_people, nil, name: NAME_KANA_INDEX)

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY #{NAME_KANA_INDEX} ON snapshot_people
      USING gin ((extra_profile ->> 'name_kana') gin_trgm_ops)
    SQL
  end

  def down
    INDEXES.each do |table, _column, name|
      remove_index table, name:, algorithm: :concurrently, if_exists: true
    end
    execute "DROP INDEX CONCURRENTLY IF EXISTS #{NAME_KANA_INDEX}"
  end

  private

  def existing_trgm_index_name(table, column)
    select_value(<<~SQL.squish)
      SELECT indexname FROM pg_indexes
      WHERE schemaname = current_schema()
        AND tablename = #{connection.quote(table.to_s)}
        AND indexdef ILIKE #{connection.quote("%(#{column} gin_trgm_ops)%")}
      LIMIT 1
    SQL
  end
end

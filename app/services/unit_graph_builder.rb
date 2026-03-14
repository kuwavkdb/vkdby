# frozen_string_literal: true

class UnitGraphBuilder # rubocop:disable Metrics/ClassLength
  def initialize(unit, track_past: false)
    @unit = unit
    @track_past = track_past
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: 24.hours) { compute }
  end

  private

  def cache_key
    latest = UnitSnapshot.maximum(:updated_at)
    "unit_graph/#{@unit.id}/v20/#{@track_past ? 'past' : 'cur'}/#{latest.to_i}"
  end

  def compute
    hop1_person_ids = fetch_hop1_person_ids
    return { nodes: [], edges: [] } if hop1_person_ids.empty?

    hop1_unit_ids = fetch_unit_ids_for_persons(hop1_person_ids) # カレントのみ（エッジ実線判定用）

    # track_past=true: カレント中心メンバーの全履歴ユニットを起点にhop2を展開
    # track_past=false: カレント在籍ユニットのみ（デフォルト）
    hop2_source_unit_ids = if @track_past
                             fetch_all_unit_ids_for_persons(hop1_person_ids) - [@unit.id]
                           else
                             hop1_unit_ids - [@unit.id]
                           end

    all_center_person_ids = fetch_all_center_person_ids
    hop2_person_ids = fetch_hop2_person_ids(hop2_source_unit_ids)
    all_person_ids = (all_center_person_ids + hop2_person_ids).uniq

    unit_ids_by_person = build_person_unit_map(all_person_ids)
    relevant_unit_ids = resolve_relevant_unit_ids(unit_ids_by_person, [@unit.id] + hop2_source_unit_ids)

    unit_ids_by_person.transform_values! { |uids| uids & relevant_unit_ids }
    unit_ids_by_person.reject! { |_pid, uids| uids.size < 2 }

    # 中心に近い側のユニットでカレントメンバーなら実線（同階層の場合はいずれか一方でも可）
    current_edge_pairs = build_current_edge_pairs(all_person_ids, unit_ids_by_person, hop1_unit_ids)

    # hop1（グラフ距離1）の色付け対象:
    #   track_past=false: カレントメンバーを経由するユニットのみをhop1（紫）とする
    #   track_past=true : 過去メンバーを含む全歴史メンバー経由のユニットもhop1とする
    center_pids_for_hop1 = @track_past ? all_center_person_ids.to_set : hop1_person_ids.to_set
    hop1_display_unit_ids = unit_ids_by_person
                            .select { |pid, uids| center_pids_for_hop1.include?(pid) && uids.include?(@unit.id) }
                            .values.flatten.uniq.to_set - Set[@unit.id]

    build_graph(unit_ids_by_person, current_edge_pairs, relevant_unit_ids, hop1_display_unit_ids)
  end

  def fetch_hop1_person_ids
    snapshot_ids = @unit.unit_snapshots.where(current: true).select(:id)
    SnapshotPerson.where(unit_snapshot_id: snapshot_ids)
                  .where.not(person_id: nil)
                  .pluck(:person_id).uniq
  end

  # 中心ユニットの全スナップショット（過去含む）に登場した全メンバー
  def fetch_all_center_person_ids
    snapshot_ids = @unit.unit_snapshots.select(:id)
    SnapshotPerson.where(unit_snapshot_id: snapshot_ids)
                  .where.not(person_id: nil)
                  .pluck(:person_id).uniq
  end

  def fetch_unit_ids_for_persons(person_ids)
    SnapshotPerson
      .joins(:unit_snapshot)
      .where(unit_snapshots: { current: true })
      .where(person_id: person_ids)
      .pluck('unit_snapshots.unit_id').uniq
  end

  def fetch_hop2_person_ids(adjacent_unit_ids)
    snapshot_ids = UnitSnapshot.where(unit_id: adjacent_unit_ids, current: true).select(:id)
    SnapshotPerson.where(unit_snapshot_id: snapshot_ids)
                  .where.not(person_id: nil)
                  .pluck(:person_id).uniq
  end

  def fetch_all_unit_ids_for_persons(person_ids)
    SnapshotPerson
      .joins(:unit_snapshot)
      .where(person_id: person_ids)
      .pluck('unit_snapshots.unit_id').uniq
  end

  def build_person_unit_map(person_ids)
    SnapshotPerson
      .joins(:unit_snapshot)
      .where(person_id: person_ids)
      .pluck(:person_id, 'unit_snapshots.unit_id')
      .each_with_object(Hash.new { |h, k| h[k] = [] }) { |(pid, uid), h| h[pid] << uid }
      .transform_values(&:uniq)
  end

  # エッジの実線/破線用:
  #   異なるhop間のエッジ → 中心に近い側（hop1）でカレントメンバーなら実線
  #   同じhop階層のエッジ → いずれか一方でもカレントメンバーなら実線
  def build_current_edge_pairs(all_person_ids, unit_ids_by_person, hop1_unit_ids)
    current_unit_ids_by_person = SnapshotPerson
                                 .joins(:unit_snapshot)
                                 .where(unit_snapshots: { current: true })
                                 .where(person_id: all_person_ids)
                                 .pluck(:person_id, 'unit_snapshots.unit_id')
                                 .each_with_object(Hash.new { |h, k| h[k] = [] }) { |(pid, uid), h| h[pid] << uid }
                                 .transform_values(&:uniq)

    hop1_set = hop1_unit_ids.to_set
    pairs = Set.new
    unit_ids_by_person.each do |person_id, uids|
      current_uid_set = (current_unit_ids_by_person[person_id] || []).to_set
      next if current_uid_set.empty?

      uids.combination(2).each do |a, b|
        a_inner = hop1_set.include?(a)
        b_inner = hop1_set.include?(b)

        solid = if a_inner && !b_inner
                  current_uid_set.include?(a)   # A が内側: A でカレントなら実線
                elsif b_inner && !a_inner
                  current_uid_set.include?(b)   # B が内側: B でカレントなら実線
                else
                  current_uid_set.include?(a) || current_uid_set.include?(b) # 同階層
                end

        pairs.add([a, b].sort) if solid
      end
    end
    pairs
  end

  def resolve_relevant_unit_ids(unit_ids_by_person, hop1_unit_ids)
    hop2_unit_ids = unit_ids_by_person
                    .select { |_pid, uids| (uids & hop1_unit_ids).any? }
                    .values.flatten.uniq
    (hop1_unit_ids + hop2_unit_ids).uniq
  end

  def build_graph(unit_ids_by_person, current_edge_pairs, relevant_unit_ids, hop1_unit_ids_set = Set.new)
    related_units = Unit.where(id: relevant_unit_ids).index_by(&:id)

    nodes = { "unit_#{@unit.id}" => center_node }
    edges = {}

    unit_ids_by_person.each_value do |uids|
      uids.combination(2).each do |uid_a, uid_b|
        uid_a, uid_b = [uid_a, uid_b].sort
        edge_key = "e_#{uid_a}_#{uid_b}"
        edge_current = current_edge_pairs.include?([uid_a, uid_b])

        [uid_a, uid_b].each do |uid|
          next if nodes["unit_#{uid}"]

          u = related_units[uid]
          next unless u

          hop_level = if uid == @unit.id then 0
                      elsif hop1_unit_ids_set.include?(uid) then 1
                      else 2
                      end
          # hop1 = 紫、hop2 = グレー（hopのみで色分け）
          nodes["unit_#{uid}"] = unit_node(u, uid == @unit.id, hop_level == 1, hop_level)
        end

        if edges[edge_key]
          edges[edge_key][:data][:current] = 1 if edge_current
        else
          edges[edge_key] = { data: { id: edge_key, source: "unit_#{uid_a}", target: "unit_#{uid_b}",
                                      current: edge_current ? 1 : 0 } }
        end
      end
    end

    { nodes: nodes.values, edges: edges.values }
  end

  def center_node
    { data: { id: "unit_#{@unit.id}", label: @unit.name, type: 'unit',
              url: "/#{@unit.key}#relationship-graph",
              graph_url: "/#{@unit.key}/relationship_graph",
              hop: 0 },
      classes: 'center snapshot-current' }
  end

  def unit_node(unit, is_center, is_current, hop_level = 1)
    classes = []
    classes << 'center' if is_center
    classes << 'snapshot-current' if is_current
    { data: { id: "unit_#{unit.id}", label: unit.name, type: 'unit',
              url: "/#{unit.key}#relationship-graph",
              graph_url: "/#{unit.key}/relationship_graph",
              hop: hop_level },
      classes: classes.join(' ') }
  end
end

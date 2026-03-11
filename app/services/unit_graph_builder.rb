# frozen_string_literal: true

class UnitGraphBuilder
  def initialize(unit)
    @unit = unit
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: 24.hours) { compute }
  end

  private

  def cache_key
    latest = UnitSnapshot.where(current: true).maximum(:updated_at)
    "unit_graph/#{@unit.id}/#{latest.to_i}"
  end

  def compute
    hop1_person_ids = fetch_hop1_person_ids
    return { nodes: [], edges: [] } if hop1_person_ids.empty?

    hop1_unit_ids = fetch_unit_ids_for_persons(hop1_person_ids)
    hop2_person_ids = fetch_hop2_person_ids(hop1_unit_ids)
    all_person_ids = (hop1_person_ids + hop2_person_ids).uniq

    unit_ids_by_person = build_person_unit_map(all_person_ids)
    relevant_unit_ids = resolve_relevant_unit_ids(unit_ids_by_person, hop1_unit_ids)

    unit_ids_by_person.transform_values! { |uids| uids & relevant_unit_ids }
    unit_ids_by_person.reject! { |_pid, uids| uids.size < 2 }

    build_graph(unit_ids_by_person, relevant_unit_ids)
  end

  def fetch_hop1_person_ids
    snapshot_ids = @unit.unit_snapshots.where(current: true).select(:id)
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

  def fetch_hop2_person_ids(hop1_unit_ids)
    snapshot_ids = UnitSnapshot.where(unit_id: hop1_unit_ids - [@unit.id], current: true).select(:id)
    SnapshotPerson.where(unit_snapshot_id: snapshot_ids)
                  .where.not(person_id: nil)
                  .pluck(:person_id).uniq
  end

  def build_person_unit_map(person_ids)
    SnapshotPerson
      .joins(:unit_snapshot)
      .where(unit_snapshots: { current: true })
      .where(person_id: person_ids)
      .pluck(:person_id, 'unit_snapshots.unit_id')
      .each_with_object(Hash.new { |h, k| h[k] = [] }) { |(pid, uid), h| h[pid] << uid }
  end

  def resolve_relevant_unit_ids(unit_ids_by_person, hop1_unit_ids)
    hop2_unit_ids = unit_ids_by_person
                    .select { |_pid, uids| (uids & hop1_unit_ids).any? }
                    .values.flatten.uniq
    (hop1_unit_ids + hop2_unit_ids).uniq
  end

  def build_graph(unit_ids_by_person, relevant_unit_ids)
    related_units = Unit.where(id: relevant_unit_ids).index_by(&:id)
    nodes = { "unit_#{@unit.id}" => center_node }
    edges = {}

    unit_ids_by_person.each_value do |uids|
      uids.combination(2).each do |uid_a, uid_b|
        uid_a, uid_b = [uid_a, uid_b].sort
        edge_key = "e_#{uid_a}_#{uid_b}"
        next if edges[edge_key]

        [uid_a, uid_b].each do |uid|
          next if nodes["unit_#{uid}"]

          u = related_units[uid]
          next unless u

          nodes["unit_#{uid}"] = unit_node(u, uid == @unit.id)
        end

        edges[edge_key] = { data: { id: edge_key, source: "unit_#{uid_a}", target: "unit_#{uid_b}" } }
      end
    end

    { nodes: nodes.values, edges: edges.values }
  end

  def center_node
    { data: { id: "unit_#{@unit.id}", label: @unit.name, type: 'unit',
              url: "/#{@unit.key}#relationship-graph",
              graph_url: "/#{@unit.key}/relationship_graph",
              current: true } }
  end

  def unit_node(unit, current)
    { data: { id: "unit_#{unit.id}", label: unit.name, type: 'unit',
              url: "/#{unit.key}#relationship-graph",
              graph_url: "/#{unit.key}/relationship_graph",
              current: } }
  end
end

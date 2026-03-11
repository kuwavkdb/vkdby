# frozen_string_literal: true

class ProfilesController < ApplicationController
  def show
    @resource = Unit.kept.includes(:links).find_by(key: params[:key]) ||
                Person.kept.includes(:links).find_by!(key: params[:key])

    @links = @resource.links.where(active: true).order(:sort_order)

    @resource.is_a?(Person) ? load_person_data : load_unit_data
    load_items

    respond_to do |format|
      format.html
      format.json { render json: @resource }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { render file: Rails.root.join('public/404.html'), status: :not_found, layout: false }
      format.json { render json: { error: 'Resource not found' }, status: :not_found }
    end
  end

  def update_logs
    @resource = Unit.kept.find_by(key: params[:key]) ||
                Person.kept.find_by!(key: params[:key])

    update_logs = if @resource.is_a?(Unit)
                    UpdateLog.for_unit(@resource)
                  else
                    UpdateLog.for_person(@resource)
                  end
                  .includes(:user)
                  .order(created_at: :desc)
                  .limit(50)

    render partial: 'update_logs', locals: { update_logs: }
  rescue ActiveRecord::RecordNotFound
    render plain: '', status: :not_found
  end

  def snapshot_members
    unit = Unit.kept.find_by!(key: params[:key])
    snapshot = unit.unit_snapshots.find(params[:id])
    render partial: 'snapshot_members',
           locals: { snapshot_people: snapshot.snapshot_people.includes(:person).sort_by(&:sort_order),
                     snapshot: snapshot }
  rescue ActiveRecord::RecordNotFound
    render plain: '', status: :not_found
  end

  private

  def load_person_data
    @logs = @resource.person_logs.order(:sort_order, :log_date)

    # person_logsが無く、old_historyがある場合はパースして使用
    @old_history_items = @resource.parse_old_history if @logs.empty? && @resource.old_history.present?

    @trends = Trend.where('people @> ?', [{ person_id: @resource.id }].to_json)
                   .order(date: :desc)
                   .limit(10)
  end

  def load_unit_data
    # ユニットの履歴を統合 (UnitLog + PersonLog)
    unit_logs = @resource.unit_logs
    person_logs = @resource.person_logs.includes(:person)
    @history = (unit_logs + person_logs).sort_by { |l| [l.log_date.to_s, l.is_a?(PersonLog) ? 1 : 0] }

    @trends = Trend.where('units @> ?', [{ unit_id: @resource.id }].to_json)
                   .order(date: :desc)
                   .limit(10)

    @snapshots = @resource.unit_snapshots
                          .active
                          .includes(snapshot_people: :person)
                          .order(past: :asc, current: :desc, snapshot_index: :asc)

    @graph_data = build_unit_graph_data(@resource)
  end

  def build_unit_graph_data(unit)
    current_snapshot_ids = unit.unit_snapshots.where(current: true).select(:id)
    person_ids = SnapshotPerson.where(unit_snapshot_id: current_snapshot_ids)
                               .where.not(person_id: nil)
                               .pluck(:person_id)
                               .uniq

    return { nodes: [], edges: [] } if person_ids.empty?

    # person_id → [unit_id, ...] のマップを構築
    unit_ids_by_person = SnapshotPerson
      .joins(:unit_snapshot)
      .where(unit_snapshots: { current: true })
      .where(person_id: person_ids)
      .pluck(:person_id, "unit_snapshots.unit_id")
      .each_with_object(Hash.new { |h, k| h[k] = [] }) { |(pid, uid), h| h[pid] << uid }

    # 関連する全 unit_id を収集
    related_unit_ids = unit_ids_by_person.values.flatten.uniq
    related_units = Unit.where(id: related_unit_ids).index_by(&:id)

    nodes = {}
    edges = {}

    # 中心ユニットノード
    nodes["unit_#{unit.id}"] = { data: { id: "unit_#{unit.id}", label: unit.name, type: "unit", url: "/#{unit.key}", current: true } }

    # 共通メンバーを持つ Unit ペアにエッジを張る
    unit_ids_by_person.each do |_person_id, uids|
      uids.combination(2).each do |uid_a, uid_b|
        uid_a, uid_b = [uid_a, uid_b].sort
        edge_key = "e_#{uid_a}_#{uid_b}"
        next if edges[edge_key]

        [uid_a, uid_b].each do |uid|
          next if nodes["unit_#{uid}"]
          u = related_units[uid]
          next unless u
          nodes["unit_#{uid}"] = { data: { id: "unit_#{uid}", label: u.name, type: "unit", url: "/#{u.key}", current: uid == unit.id } }
        end

        edges[edge_key] = { data: { id: edge_key, source: "unit_#{uid_a}", target: "unit_#{uid_b}" } }
      end
    end

    { nodes: nodes.values, edges: edges.values }
  end

  def load_items
    scopes = []
    scopes << Item.by_artist_key(@resource.key) if @resource.key.present?
    scopes << Item.by_artist_old_key(@resource.old_key) if @resource.old_key.present?
    return if scopes.empty?

    query = scopes.reduce(:or)
    @items_count = query.count
    @items = query.order(release_date: :desc).limit(10)
  end
end

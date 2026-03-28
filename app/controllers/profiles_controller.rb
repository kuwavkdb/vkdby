# frozen_string_literal: true

class ProfilesController < ApplicationController
  def show
    @resource = Unit.kept.includes(:links).find_by(key: params[:key]) ||
                Person.kept.includes(:links).find_by!(key: params[:key])

    if @resource.is_a?(Unit) && @resource.destination_key.present?
      redirect_to profile_path(@resource.destination_key), status: :moved_permanently
      return
    end

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

  def relationship_graph
    unit = Unit.kept.find_by!(key: params[:key])
    track_past = params[:track_past] == '1'
    render json: UnitGraphBuilder.new(unit, track_past:).call
  rescue ActiveRecord::RecordNotFound
    render json: { nodes: [], edges: [] }, status: :not_found
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
    @old_history_items = @resource.parse_old_history if @resource.old_history.present?

    @trends = Trend.where('people @> ?', [{ person_id: @resource.id }].to_json)
                   .order(date: :desc)
                   .limit(10)
  end

  def load_unit_data
    @history = @resource.unit_logs

    @trends = Trend.where('units @> ?', [{ unit_id: @resource.id }].to_json)
                   .order(date: :desc)
                   .limit(10)

    @snapshots = @resource.unit_snapshots
                          .active
                          .includes(snapshot_people: :person)
                          .order(past: :asc, current: :desc, snapshot_index: :asc)
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

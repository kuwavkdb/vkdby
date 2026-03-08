# frozen_string_literal: true

class ProfilesController < ApplicationController
  def show
    @resource = Unit.kept.includes(:links).find_by(key: params[:key]) ||
                Person.kept.includes(:links).find_by!(key: params[:key])

    @links = @resource.links.where(active: true).order(:sort_order)

    @resource.is_a?(Person) ? load_person_data : load_unit_data
    load_items
    load_update_logs

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
                          .includes(snapshot_people: :person)
                          .order(past: :asc, current: :desc, snapshot_index: :asc)
  end

  def load_update_logs
    @update_logs = UpdateLog.where(loggable: @resource)
                            .includes(:user)
                            .order(created_at: :desc)
                            .limit(10)
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

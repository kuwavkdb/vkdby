# frozen_string_literal: true

class ProfilesController < ApplicationController
  def show
    @resource = Unit.with_discarded.includes(:links).find_by(key: params[:key]) ||
                Person.with_discarded.includes(:links).find_by(key: params[:key])

    raise ActiveRecord::RecordNotFound unless @resource

    if @resource.destination_key.present?
      redirect_to profile_path(@resource.destination_key), status: :moved_permanently
      return
    end

    raise ActiveRecord::RecordNotFound if @resource.discarded?

    @unpublished = @resource.unpublished?

    unless @unpublished
      @links = @resource.links.where(active: true).order(:sort_order)
      @youtube_links = @links.select { |l| l.youtube_video_id.present? }
      @twitter_links = @links.select(&:twitter_status_url?)
      @links_for_list = @links - @youtube_links - @twitter_links

      @resource.is_a?(Person) ? load_person_data : load_unit_data
      load_items
      load_same_kana_resources
    end

    respond_to do |format|
      format.html
      format.json { render json: @resource }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { render_not_found(query: params[:key]) }
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
    @history = @resource.unit_logs.select(:id, :log_date, :phenomenon, :phenomenon_alias, :text)

    @trends = Trend.where('units @> ?', [{ unit_id: @resource.id }].to_json)
                   .order(date: :desc)
                   .limit(10)

    trend_unit_ids = @trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
    @trend_related_units = Unit.kept.where(id: trend_unit_ids).index_by(&:id)

    @snapshots = @resource.unit_snapshots
                          .active
                          .includes(:snapshot_people)
                          .order(past: :asc, current: :desc, snapshot_index: :asc)

    # MemberRowComponent（カレントスナップショットの表示）は person 関連が必要だが、
    # 非カレントは member_names のテキストのみ参照するため、person の eager load を
    # カレントスナップショットの snapshot_people に限定してメモリ消費を抑える。
    current_snapshot_people = @snapshots.select(&:current?).flat_map(&:snapshot_people)
    ActiveRecord::Associations::Preloader.new(records: current_snapshot_people, associations: :person).call
  end

  def load_same_kana_resources
    return if @resource.name_kana.blank?

    scope = @resource.class.kept.where(name_kana: @resource.name_kana).where.not(id: @resource.id)
    @same_kana_total = scope.count
    @same_kana_resources = scope.order(updated_at: :desc).limit(6) if @same_kana_total.positive?
  end

  def load_items
    scopes = []
    scopes << Item.kept.by_artist_key(@resource.key) if @resource.key.present?
    scopes << Item.kept.by_artist_old_key(@resource.old_key) if @resource.old_key.present?
    return if scopes.empty?

    query = scopes.reduce(:or)
    @items_count = query.count
    @items = query.order(release_date: :desc).limit(10)
  end
end

# frozen_string_literal: true

module Admin
  class UnitsController < Admin::BaseController # rubocop:disable Metrics/ClassLength
    include LoggableLinkChanges

    before_action :set_unit, only: %i[show edit update destroy undiscard change_key purge]
    before_action :require_super_operator, only: %i[destroy]
    before_action :require_admin, only: %i[change_key purge bulk_update_status]

    def index
      @q = params[:q]
      @tag_index_id = params[:tag_index_id]
      @show_discarded = @tag_index_id.present? ? 'all' : params[:discarded]
      @unit_type_filter = params[:unit_type]
      @redirect_source = params[:redirect_source]
      @status_filter = params[:status]
      scope = case @show_discarded
              when 'only' then Unit.discarded
              when 'all'  then Unit.with_discarded
              else             Unit.kept
              end
      if @redirect_source == 'only'
        scope = Unit.with_discarded.where.not(destination_key: nil)
      elsif @unit_type_filter == 'moved'
        scope = scope.where(unit_type: :moved)
      elsif @show_discarded.blank? && @tag_index_id.blank?
        scope = scope.where.not(unit_type: :moved)
      end
      if @q.present?
        scope = scope.where(
          'name ILIKE :q OR name_kana ILIKE :q OR key ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q',
          q: "%#{@q}%"
        )
      end
      if @tag_index_id.present?
        @tag_index = TagIndex.find_by(id: @tag_index_id)
        scope = scope.joins(:tag_index_items).where(tag_index_items: { tag_index_id: @tag_index_id })
      end
      scope = scope.where(status: @status_filter) if @status_filter.present?
      @pagy, @units = pagy(scope.order(updated_at: :desc))
      @tag_filter_groups = IndexGroup.tag_filter_options_for_units
    end

    def new
      @unit = Unit.new(params[:unit]&.permit(:name, :key, :name_kana, :status, :unit_type, :old_key))
      @unit.name ||= params[:name]
      @unit.old_key ||= params[:old_key]
    end

    def show
      redirect_to edit_admin_unit_path(@unit)
    end

    def edit
      @unit_logs = @unit.unit_logs.order(:log_date)
      @unit_snapshots = @unit.unit_snapshots.includes(snapshot_people: :person).order(snapshot_date: :desc)
      @unit.links.build # Build an empty link for the form
      @wiki_page_imports = @unit.wiki_page_imports.includes(:wikipage).order(updated_at: :desc)
      @update_logs = UpdateLog.for_unit(@unit)
                              .includes(:user)
                              .order(created_at: :desc)
                              .limit(50)
    end

    def create
      @unit = Unit.new(unit_params)

      if @unit.save
        record_update_log(@unit, action: 'create')
        redirect_to admin_units_path, notice: 'Unit created successfully.'
      else
        @unit.links.build if @unit.links.none?(&:new_record?)
        render :new, status: :unprocessable_entity
      end
    end

    def update
      pre_link_ids = @unit.links.pluck(:id)

      if @unit.update(unit_update_params)
        record_update_log(@unit, action: 'update')
        record_link_changes(@unit, pre_link_ids)
        redirect_to edit_admin_unit_path(@unit), notice: 'Unit updated successfully.'
      else
        @unit_logs = @unit.unit_logs.order(:log_date)
        @unit_snapshots = @unit.unit_snapshots.includes(snapshot_people: :person).order(snapshot_date: :desc)
        @unit.links.build if @unit.links.none?(&:new_record?)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @unit.discard
      record_update_log(@unit, action: 'discard')
      redirect_to admin_units_path, notice: 'Unit deleted successfully.'
    end

    def undiscard
      @unit.undiscard
      record_update_log(@unit, action: 'undiscard')
      redirect_to admin_units_path, notice: 'Unit restored successfully.'
    end

    def change_key
      new_key = params[:new_key].to_s.strip

      if new_key.blank?
        redirect_to edit_admin_unit_path(@unit), alert: 'New key is required.'
        return
      end

      @unit.change_key!(new_key)
      record_update_log(@unit, action: 'change_key')
      redirect_to edit_admin_unit_path(@unit), notice: 'Key changed successfully.'
    rescue ActiveRecord::RecordNotUnique
      redirect_to edit_admin_unit_path(@unit), alert: 'That key is already in use.'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to edit_admin_unit_path(@unit), alert: e.message
    end

    def purge
      unless @unit.redirect_source?
        redirect_to admin_units_path(redirect_source: 'only'), alert: 'リダイレクト元のレコードのみ物理削除できます。'
        return
      end

      if Item.by_artist_key(@unit.key).exists?
        redirect_to admin_units_path(redirect_source: 'only'), alert: 'このキーはまだ作品から参照されているため物理削除できません。'
        return
      end

      key_was = @unit.key
      destination_was = @unit.destination_key
      @unit.destroy!
      UpdateLog.create!(
        user: current_user,
        action: 'purge',
        loggable_type: 'Unit',
        loggable_id: @unit.id,
        diff: { 'key' => [key_was, nil], 'destination_key' => [destination_was, nil] }
      )
      redirect_to admin_units_path(redirect_source: 'only'), notice: 'リダイレクト元レコードを物理削除しました。'
    end

    def bulk_update_status
      ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
      status = params[:status].presence
      return redirect_back_or_to admin_units_path, alert: '項目が選択されていません' if ids.empty?
      return redirect_back_or_to admin_units_path, alert: 'Statusを選択してください' unless Unit.statuses.key?(status)

      count = 0
      Unit.with_discarded.where(id: ids).find_each do |unit|
        next if unit.status == status

        unit.update!(status: status)
        record_update_log(unit, action: 'update')
        count += 1
      end
      redirect_back_or_to admin_units_path, notice: "#{count}件のStatusを更新しました"
    end

    def search
      q = params[:q]
      scope = Unit.kept

      if q.present?
        scope = scope.where(
          'name ILIKE :q OR name_kana ILIKE :q OR key ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q',
          q: "%#{q}%"
        )
      end

      @units = scope.limit(10).order(:name)

      render json: @units.map { |u| { id: u.id, name: u.name, name_kana: u.name_kana, key: u.key, destination_key: u.destination_key } }
    end

    private

    def set_unit
      @unit = Unit.with_discarded.find(params[:id])
    end

    def unit_params
      params.require(:unit).permit(:name, :name_kana, :key, :status, :unit_type, :old_key, :destination_key, :note,
                                   tag_index_ids: [],
                                   links_attributes: %i[id text url active sort_order _destroy],
                                   name_logs_attributes: %i[name name_kana],
                                   aliases_attributes: %i[name kana old_key],
                                   activity_periods_attributes: %i[from to label])
    end

    # key はキー変更専用の操作でのみ変更可能(issue #57)。通常の update では受け付けない。
    def unit_update_params
      unit_params.except(:key)
    end
  end
end

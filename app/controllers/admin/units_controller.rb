# frozen_string_literal: true

module Admin
  class UnitsController < Admin::BaseController
    include LoggableLinkChanges

    before_action :set_unit, only: %i[show edit update destroy undiscard]
    before_action :require_super_operator, only: %i[destroy]

    def index
      @q = params[:q]
      @show_discarded = params[:discarded]
      scope = case @show_discarded
              when 'only' then Unit.discarded
              when 'all'  then Unit.with_discarded
              else             Unit.kept
              end
      if @q.present?
        scope = scope.where(
          'name ILIKE :q OR name_kana ILIKE :q OR key ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q',
          q: "%#{@q}%"
        )
      end
      @pagy, @units = pagy(scope.order(updated_at: :desc))
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
      @unit_people = @unit.unit_people.includes(:person).order(:period, :order_in_period)
      @unit_person = @unit.unit_people.build(period: 1, order_in_period: (@unit_people.last&.order_in_period || 0) + 1)
      @unit_snapshots = @unit.unit_snapshots.includes(snapshot_people: :person).order(snapshot_date: :desc)
      @unit.links.build # Build an empty link for the form
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

      if @unit.update(unit_params)
        record_update_log(@unit, action: 'update')
        record_link_changes(@unit, pre_link_ids)
        redirect_to edit_admin_unit_path(@unit), notice: 'Unit updated successfully.'
      else
        @unit_logs = @unit.unit_logs.order(:log_date)
        @unit_people = @unit.unit_people.includes(:person).order(:period, :order_in_period)
        @unit_person = @unit.unit_people.build(period: 1,
                                               order_in_period: (@unit_people.last&.order_in_period || 0) + 1)
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

      render json: @units.map { |u| { id: u.id, name: u.name, name_kana: u.name_kana, key: u.key } }
    end

    private

    def set_unit
      @unit = Unit.with_discarded.find(params[:id])
    end

    def unit_params
      params.require(:unit).permit(:name, :name_kana, :key, :status, :unit_type, :old_key, :note,
                                   links_attributes: %i[id text url active sort_order _destroy],
                                   name_logs_attributes: %i[name name_kana],
                                   aliases_attributes: %i[name kana],
                                   activity_periods_attributes: %i[from to label])
    end
  end
end

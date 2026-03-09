# frozen_string_literal: true

module Admin
  class UnitSnapshotsController < Admin::BaseController
    before_action :set_unit
    before_action :set_unit_snapshot, only: %i[edit update destroy copy]

    def index
      @unit_snapshots = @unit.unit_snapshots.includes(snapshot_people: :person)
                             .order(snapshot_date: :desc)
    end

    def new
      @unit_snapshot = @unit.unit_snapshots.build
    end

    def edit
      @snapshot_people = @unit_snapshot.snapshot_people.includes(:person).order(:sort_order)
      @snapshot_person = @unit_snapshot.snapshot_people.build
    end

    def create
      @unit_snapshot = @unit.unit_snapshots.build(unit_snapshot_params)

      if @unit_snapshot.save
        record_update_log(@unit_snapshot, action: 'create')
        redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                    notice: 'Snapshot was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @unit_snapshot.update(unit_snapshot_params)
        record_update_log(@unit_snapshot, action: 'update')
        redirect_to admin_unit_unit_snapshots_path(@unit),
                    notice: 'Snapshot was successfully updated.'
      else
        @snapshot_people = @unit_snapshot.snapshot_people.includes(:person).order(:sort_order)
        @snapshot_person = @unit_snapshot.snapshot_people.build
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @unit_snapshot.destroy
      record_update_log(@unit_snapshot, action: 'discard')
      redirect_to admin_unit_unit_snapshots_path(@unit),
                  notice: 'Snapshot was successfully destroyed.'
    end

    def copy
      new_snapshot = @unit.unit_snapshots.build(
        snapshot_date: @unit_snapshot.snapshot_date,
        label: @unit_snapshot.label,
        current: false,
        past: @unit_snapshot.past,
        active: false
      )

      if new_snapshot.save
        @unit_snapshot.snapshot_people.each do |sp|
          new_snapshot.snapshot_people.create!(sp.attributes.except('id', 'unit_snapshot_id', 'created_at', 'updated_at'))
        end
        record_update_log(new_snapshot, action: 'create')
        redirect_to edit_admin_unit_unit_snapshot_path(@unit, new_snapshot),
                    notice: 'Snapshot was successfully copied.'
      else
        redirect_to admin_unit_unit_snapshots_path(@unit),
                    alert: 'Failed to copy snapshot.'
      end
    end

    def reorder
      params[:ids].each_with_index do |id, index|
        @unit.unit_snapshots.find(id).update(snapshot_index: index + 1)
      end
      head :ok
    end

    private

    def set_unit
      @unit = Unit.find(params[:unit_id])
    end

    def set_unit_snapshot
      @unit_snapshot = @unit.unit_snapshots.find(params[:id])
    end

    def unit_snapshot_params
      params.require(:unit_snapshot).permit(:snapshot_date, :label, :current, :active)
    end
  end
end

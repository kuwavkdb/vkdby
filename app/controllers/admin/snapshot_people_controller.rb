# frozen_string_literal: true

module Admin
  class SnapshotPeopleController < Admin::BaseController
    before_action :set_unit
    before_action :set_unit_snapshot

    def create
      @snapshot_person = @unit_snapshot.snapshot_people.build(snapshot_person_params)

      if @snapshot_person.save
        redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                    notice: 'Member was successfully added.'
      else
        redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                    alert: "Failed to add member: #{@snapshot_person.errors.full_messages.join(', ')}"
      end
    end

    def destroy
      @snapshot_person = @unit_snapshot.snapshot_people.find(params[:id])
      @snapshot_person.destroy
      redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                  notice: 'Member was successfully removed.'
    end

    private

    def set_unit
      @unit = Unit.find(params[:unit_id])
    end

    def set_unit_snapshot
      @unit_snapshot = @unit.unit_snapshots.find(params[:unit_snapshot_id])
    end

    def snapshot_person_params
      params.require(:snapshot_person).permit(:person_id, :person_name, :part, :sort_order)
    end
  end
end

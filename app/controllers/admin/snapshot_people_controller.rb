# frozen_string_literal: true

module Admin
  class SnapshotPeopleController < Admin::BaseController
    before_action :set_unit
    before_action :set_unit_snapshot
    before_action :set_snapshot_person, only: %i[edit update destroy]

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

    def edit; end

    def update
      if @snapshot_person.update(snapshot_person_params)
        redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                    notice: 'Member was successfully updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @snapshot_person.destroy
      redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                  notice: 'Member was successfully removed.'
    end

    def reorder
      params[:ids].each_with_index do |id, index|
        @unit_snapshot.snapshot_people.find(id).update(sort_order: index + 1)
      end
      head :ok
    end

    private

    def set_unit
      @unit = Unit.find(params[:unit_id])
    end

    def set_unit_snapshot
      @unit_snapshot = @unit.unit_snapshots.find(params[:unit_snapshot_id])
    end

    def set_snapshot_person
      @snapshot_person = @unit_snapshot.snapshot_people.find(params[:id])
    end

    def snapshot_person_params
      p = params.require(:snapshot_person).permit(
        :person_id, :person_name, :name_alias, :part, :part_alias,
        :status, :support, :sort_order, :person_key, :old_person_key,
        :inline_history, :sns
      )
      p[:person_id] = nil if p[:person_id].to_i.zero?

      if p[:sns].is_a?(String)
        p[:sns] = p[:sns].split("\n").map(&:strip).reject(&:blank?)
        p[:sns] = nil if p[:sns].empty?
      end

      p
    end
  end
end

# frozen_string_literal: true

module Admin
  class UnitPeopleController < Admin::BaseController
    before_action :set_unit
    before_action :set_unit_person, only: %i[edit update destroy]

    def create
      @unit_person = @unit.unit_people.build(unit_person_params)

      if @unit_person.save
        redirect_to edit_admin_unit_path(@unit), notice: 'Member added successfully.'
      else
        redirect_to edit_admin_unit_path(@unit),
                    alert: "Failed to add member: #{@unit_person.errors.full_messages.join(', ')}"
      end
    end

    def edit; end

    def update
      if @unit_person.update(unit_person_params)
        redirect_to edit_admin_unit_path(@unit), notice: 'Member updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @unit_person.destroy
      redirect_to edit_admin_unit_path(@unit), notice: 'Member removed successfully.'
    end

    def reorder
      params[:ids].each_with_index do |id, index|
        @unit.unit_people.find(id).update(order_in_period: index + 1)
      end
      head :ok
    end

    private

    def set_unit
      @unit = Unit.find(params[:unit_id])
    end

    def set_unit_person
      @unit_person = @unit.unit_people.find(params[:id])
    end

    def unit_person_params
      p = params.require(:unit_person).permit(:person_id, :person_name, :person_key, :period, :order_in_period, :part,
                                              :status, :sns)
      p[:person_id] = nil if p[:person_id].to_i.zero?

      # Convert SNS textarea input (newline-separated) to array
      if p[:sns].is_a?(String)
        p[:sns] = p[:sns].split("\n").map(&:strip).reject(&:blank?)
        p[:sns] = nil if p[:sns].empty?
      end

      p
    end
  end
end

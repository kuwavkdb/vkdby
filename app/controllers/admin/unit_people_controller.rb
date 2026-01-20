class Admin::UnitPeopleController < Admin::BaseController
  before_action :set_unit

  def create
    @unit_person = @unit.unit_people.build(unit_person_params)

    if @unit_person.save
      redirect_to edit_admin_unit_path(@unit), notice: "Member added successfully."
    else
      redirect_to edit_admin_unit_path(@unit), alert: "Failed to add member: #{@unit_person.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    @unit_person = @unit.unit_people.find(params[:id])
    @unit_person.destroy
    redirect_to edit_admin_unit_path(@unit), notice: "Member removed successfully."
  end

  private

  def set_unit
    @unit = Unit.find(params[:unit_id])
  end

  def unit_person_params
    p = params.require(:unit_person).permit(:person_id, :person_name, :person_key, :period, :order_in_period, :part, :status)
    p[:person_id] = nil if p[:person_id].to_i == 0
    p
  end
end

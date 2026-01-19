class Admin::UnitsController < Admin::BaseController
  before_action :set_unit, only: %i[edit update destroy]
  before_action :require_super_operator, only: %i[destroy]

  def index
    @units = Unit.all.order(updated_at: :desc)
  end

  def new
    @unit = Unit.new(params[:unit]&.permit(:name, :key, :name_kana, :status, :unit_type))
  end

  def edit
    @unit_logs = @unit.unit_logs.order(:log_date)
  end

  def create
    @unit = Unit.new(unit_params)

    if @unit.save
      redirect_to admin_units_path, notice: "Unit created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @unit.update(unit_params)
      redirect_to admin_units_path, notice: "Unit updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @unit.destroy
    redirect_to admin_units_path, notice: "Unit deleted successfully."
  end

  private

  def set_unit
    @unit = Unit.find(params[:id])
  end

  def unit_params
    params.require(:unit).permit(:name, :name_kana, :key, :status, :unit_type)
  end
end

class Admin::PeopleController < Admin::BaseController
  before_action :set_person, only: %i[edit update destroy]
  before_action :require_super_operator, only: %i[destroy]

  def index
    @people = Person.all.order(updated_at: :desc)
  end

  def new
    @person = Person.new
  end

  def edit
  end

  def create
    @person = Person.new(person_params)

    if @person.save
      redirect_to admin_people_path, notice: "Person created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @person.update(person_params)
      redirect_to admin_people_path, notice: "Person updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @person.destroy
    redirect_to admin_people_path, notice: "Person deleted successfully."
  end

  private

  def set_person
    @person = Person.find(params[:id])
  end

  def person_params
    params.require(:person).permit(:name, :name_kana, :key, :birthday, :blood, :hometown, :status, :birth_year_unknown, parts: [])
  end
end

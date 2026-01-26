# frozen_string_literal: true

module Admin
  class PeopleController < Admin::BaseController
    before_action :set_person, only: %i[edit update destroy]
    before_action :require_super_operator, only: %i[destroy]

    def index
      @people = Person.all.order(updated_at: :desc)
    end

    def new
      @person = Person.new(
        key: params[:key],
        name: params[:name],
        parts: params[:parts]
      )
    end

    def edit
      @person_logs = @person.person_logs.order(:log_date)
      @person.links.build # Always add an empty link field for new entries
    end

    def create
      @person = Person.new(person_params)

      if @person.save
        redirect_to admin_people_path, notice: 'Person created successfully.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @person.update(person_params)
        redirect_to admin_people_path, notice: 'Person updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @person.destroy
      redirect_to admin_people_path, notice: 'Person deleted successfully.'
    end

    private

    def set_person
      @person = Person.find(params[:id])
    end

    def person_params
      params.require(:person).permit(
        :name, :name_kana, :birthday, :birth_year, :blood, :hometown, :status, :old_history, :note,
        parts: [],
        links_attributes: %i[id text url active _destroy],
        name_logs_attributes: %i[name name_kana]
      )
    end
  end
end

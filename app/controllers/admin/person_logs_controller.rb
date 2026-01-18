module Admin
  class PersonLogsController < BaseController
    before_action :set_person
    before_action :set_person_log, only: %i[edit update destroy]

    def reorder
      params[:ids].each_with_index do |id, index|
        @person.person_logs.find(id).update(sort_order: index)
      end
      head :ok
    end

    def index
      @person_logs = @person.person_logs.order(sort_order: :asc)
    end

    def new
      @person_log = @person.person_logs.build
    end

    def edit
    end

    def create
      @person_log = @person.person_logs.build(person_log_params)

      if @person_log.save
        redirect_to admin_person_person_logs_path(@person), notice: "Person log was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @person_log.update(person_log_params)
        redirect_to admin_person_person_logs_path(@person), notice: "Person log was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @person_log.destroy
      redirect_to admin_person_person_logs_path(@person), notice: "Person log was successfully destroyed."
    end

    private

    def set_person
      @person = Person.find(params[:person_id])
    end

    def set_person_log
      @person_log = @person.person_logs.find(params[:id])
    end

    def person_log_params
      params.require(:person_log).permit(:log_date, :status, :status_alias, :unit_id, :unit_name, :unit_key, :name, :part, :text)
    end
  end
end

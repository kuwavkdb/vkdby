# frozen_string_literal: true

module Admin
  class PeopleController < Admin::BaseController
    before_action :set_person, only: %i[edit update destroy undiscard]
    before_action :require_super_operator, only: %i[destroy]

    def index
      @q = params[:q]
      @tag_index_id = params[:tag_index_id]
      @show_discarded = @tag_index_id.present? ? 'all' : params[:discarded]
      @redirect_source = params[:redirect_source]
      scope = if @redirect_source == 'only'
                Person.with_discarded.where.not(destination_key: nil)
              else
                case @show_discarded
                when 'only' then Person.discarded
                when 'all'  then Person.with_discarded
                else             Person.kept
                end
              end
      if @q.present?
        scope = scope.where(
          'name ILIKE :q OR name_kana ILIKE :q OR key ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q OR old_history ILIKE :q',
          q: "%#{@q}%"
        )
      end
      if @tag_index_id.present?
        @tag_index = TagIndex.find_by(id: @tag_index_id)
        scope = scope.joins(:tag_index_items).where(tag_index_items: { tag_index_id: @tag_index_id })
      end
      @pagy, @people = pagy(scope.order(updated_at: :desc))
    end

    def new
      @person = Person.new(
        key: params[:key],
        name: params[:name],
        parts: params[:parts]
      )
    end

    def edit
      @person.links.build # Always add an empty link field for new entries
      @wiki_page_imports = @person.wiki_page_imports.includes(:wikipage).order(updated_at: :desc)
      @update_logs = UpdateLog.for_person(@person)
                              .includes(:user)
                              .order(created_at: :desc)
                              .limit(50)
    end

    def create
      @person = Person.new(person_params)

      if @person.save
        record_update_log(@person, action: 'create')
        redirect_to admin_people_path, notice: 'Person created successfully.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @person.update(person_params)
        record_update_log(@person, action: 'update')
        redirect_to edit_admin_person_path(@person), notice: 'Person updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @person.discard
      record_update_log(@person, action: 'discard')
      redirect_to admin_people_path, notice: 'Person deleted successfully.'
    end

    def undiscard
      @person.undiscard
      record_update_log(@person, action: 'undiscard')
      redirect_to admin_people_path, notice: 'Person restored successfully.'
    end

    def search
      q = params[:q]
      scope = Person.kept

      if q.present?
        scope = scope.where(
          'name ILIKE :q OR name_kana ILIKE :q OR key ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q',
          q: "%#{q}%"
        )
      end

      @people = scope.limit(10).order(:name)

      render json: @people.map { |p|
        { id: p.id, name: p.name.presence || p.key, name_kana: p.name_kana, key: p.key, destination_key: p.destination_key }
      }
    end

    private

    def set_person
      @person = Person.with_discarded.find(params[:id])
    end

    def person_params
      params.require(:person).permit(
        :name, :name_kana, :birthday, :birth_year, :blood, :hometown, :status, :old_history, :destination_key, :note,
        parts: [],
        tag_index_ids: [],
        links_attributes: %i[id text url active _destroy],
        name_logs_attributes: %i[name name_kana],
        aliases_attributes: %i[name kana old_key]
      )
    end
  end
end

# frozen_string_literal: true

module Admin
  class PeopleController < Admin::BaseController # rubocop:disable Metrics/ClassLength
    before_action :set_person, only: %i[edit update destroy undiscard change_key purge]
    before_action :require_super_operator, only: %i[destroy]
    before_action :require_admin, only: %i[change_key purge bulk_update_status]

    def index
      @q = params[:q]
      @tag_index_id = params[:tag_index_id]
      @show_discarded = @tag_index_id.present? ? 'all' : params[:discarded]
      @redirect_source = params[:redirect_source]
      @status_filter = params[:status]
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
      scope = scope.where(status: @status_filter) if @status_filter.present?
      @pagy, @people = pagy(scope.order(updated_at: :desc))
      @tag_filter_groups = IndexGroup.tag_filter_options_for_people
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
      # key はキー変更専用の操作でのみ変更可能(issue #57)。通常の update では受け付けない。
      if @person.update(person_params.except(:key))
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

    def change_key
      new_key = params[:new_key].to_s.strip

      if new_key.blank?
        redirect_to edit_admin_person_path(@person), alert: 'New key is required.'
        return
      end

      @person.change_key!(new_key)
      record_update_log(@person, action: 'change_key')
      redirect_to edit_admin_person_path(@person), notice: 'Key changed successfully.'
    rescue ActiveRecord::RecordNotUnique
      redirect_to edit_admin_person_path(@person), alert: 'That key is already in use.'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to edit_admin_person_path(@person), alert: e.message
    end

    def purge
      unless @person.discarded?
        redirect_to admin_people_path(redirect_source: 'only'), alert: '論理削除済みのレコードのみ物理削除できます。'
        return
      end

      if Item.by_artist_key(@person.key).exists?
        redirect_to admin_people_path(redirect_source: 'only'), alert: 'このキーはまだ作品から参照されているため物理削除できません。'
        return
      end

      if Person.with_discarded.where(destination_key: @person.key).exists?
        redirect_to admin_people_path(redirect_source: 'only'), alert: 'このキーはリダイレクト先として参照されているため物理削除できません。'
        return
      end

      # Person側から見た unit_people/snapshot_people は必ず person_id が紐づいた実在のメンバー情報なので、
      # 1件でも残っていれば物理削除しない(Unit側のインライン仮メンバー情報とは異なり道連れ削除はしない)。
      if @person.unit_people.exists?
        redirect_to admin_people_path(redirect_source: 'only'), alert: 'ユニットのメンバー情報が残っているため物理削除できません。'
        return
      end

      if @person.snapshot_people.exists?
        redirect_to admin_people_path(redirect_source: 'only'), alert: 'ユニットスナップショットのメンバー情報が残っているため物理削除できません。'
        return
      end

      key_was = @person.key
      destination_was = @person.destination_key
      ActiveRecord::Base.transaction do
        @person.destroy!
        UpdateLog.create!(
          user: current_user,
          action: 'purge',
          loggable_type: 'Person',
          loggable_id: @person.id,
          diff: { 'key' => [key_was, nil], 'destination_key' => [destination_was, nil] }
        )
      end
      redirect_to admin_people_path(redirect_source: 'only'), notice: 'リダイレクト元レコードを物理削除しました。'
    end

    def bulk_update_status
      ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
      status = params[:status].presence
      return redirect_back_or_to admin_people_path, alert: '項目が選択されていません' if ids.empty?
      return redirect_back_or_to admin_people_path, alert: 'Statusを選択してください' unless Person.statuses.key?(status)

      count = 0
      Person.with_discarded.where(id: ids).find_each do |person|
        next if person.status == status

        person.update!(status: status)
        record_update_log(person, action: 'update')
        count += 1
      end
      redirect_back_or_to admin_people_path, notice: "#{count}件のStatusを更新しました"
    end

    def search
      q = params[:q]
      scope = Person.kept

      if q.present?
        like_q = "%#{normalize_search_query(q)}%"
        # バンド（ユニット）名からもメンバーを検索できるようにする(issue #1325)
        # ユニットとの紐付けは UnitSnapshot 経由の SnapshotPerson が現行の実データ(UnitPersonは更新が止まっている)
        unit_member_ids = SnapshotPerson.joins(unit_snapshot: :unit)
                                        .merge(Unit.kept)
                                        .where('units.name ILIKE :q OR units.name_kana ILIKE :q', q: like_q)
                                        .where.not(person_id: nil)
                                        .select(:person_id)

        scope = scope.where(
          'name ILIKE :q OR name_kana ILIKE :q OR key ILIKE :q OR name_log::text ILIKE :q OR ' \
          'aliases::text ILIKE :q OR id IN (:unit_member_ids)',
          q: like_q, unit_member_ids: unit_member_ids
        )
      end

      @people = scope.limit(10).order(:name)

      render json: @people.map { |p|
        {
          id: p.id,
          name: p.name.presence || p.key,
          name_kana: p.name_kana,
          key: p.key,
          destination_key: p.destination_key,
          history_summary: person_history_summary(p)
        }
      }
    end

    private

    def person_history_summary(person)
      # 末尾が「{{category ...}}」等のステータスタグのみの場合 unit_name が空になるため、
      # unit_name を持つ項目が含まれる直近の履歴グループまで遡る
      recent_history = person.parse_old_history.reverse.find { |group| group.any? { |item| item[:unit_name].present? } }
      return nil if recent_history.blank?

      recent_history.filter_map do |item|
        next if item[:unit_name].blank?

        text = helpers.strip_tags(item[:unit_name].to_s)
        text += "(#{helpers.strip_tags(item[:part_and_name])})" if item[:part_and_name].present?
        text
      end.join('、')
    end

    def set_person
      @person = Person.with_discarded.find(params[:id])
    end

    def person_params
      params.require(:person).permit(
        :name, :key, :name_kana, :birthday, :birth_year, :blood, :hometown, :status, :old_history, :destination_key,
        :note,
        parts: [],
        tag_index_ids: [],
        links_attributes: %i[id text url active _destroy],
        name_logs_attributes: %i[name name_kana],
        aliases_attributes: %i[name kana old_key hidden]
      )
    end
  end
end

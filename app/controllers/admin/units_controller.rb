# frozen_string_literal: true

module Admin
  class UnitsController < Admin::BaseController # rubocop:disable Metrics/ClassLength
    include LoggableLinkChanges

    before_action :set_unit, only: %i[show edit update destroy undiscard change_key purge]
    before_action :require_super_operator, only: %i[destroy]
    before_action :require_admin, only: %i[change_key purge bulk_update_status]

    QUICK_CREATE_MEMBER_ROWS = 5
    QUICK_CREATE_DEFAULT_PARTS = %w[vocal guitar guitar bass drums].freeze

    def index
      @q = params[:q]
      @tag_index_id = params[:tag_index_id]
      @show_discarded = @tag_index_id.present? ? 'all' : params[:discarded]
      @unit_type_filter = params[:unit_type]
      @redirect_source = params[:redirect_source]
      @status_filter = params[:status]
      scope = case @show_discarded
              when 'only' then Unit.discarded
              when 'all'  then Unit.with_discarded
              else             Unit.kept
              end
      if @redirect_source == 'only'
        scope = Unit.with_discarded.where.not(destination_key: nil)
      elsif @unit_type_filter == 'moved'
        scope = scope.where(unit_type: :moved)
      elsif @show_discarded.blank? && @tag_index_id.blank?
        scope = scope.where.not(unit_type: :moved)
      end
      if @q.present?
        scope = scope.where(
          'name ILIKE :q OR name_kana ILIKE :q OR key ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q',
          q: "%#{@q}%"
        )
      end
      if @tag_index_id.present?
        @tag_index = TagIndex.find_by(id: @tag_index_id)
        scope = scope.joins(:tag_index_items).where(tag_index_items: { tag_index_id: @tag_index_id })
      end
      scope = scope.where(status: @status_filter) if @status_filter.present?
      @pagy, @units = pagy(scope.order(updated_at: :desc))
      @tag_filter_groups = IndexGroup.tag_filter_options_for_units
    end

    def new
      @unit = Unit.new(params[:unit]&.permit(:name, :key, :name_kana, :status, :unit_type, :old_key))
      @unit.name ||= params[:name]
      @unit.old_key ||= params[:old_key]
      prefill_from_unit_submission(@unit, params[:unit_submission_id]) if params[:unit_submission_id].present?
    end

    def show
      redirect_to edit_admin_unit_path(@unit)
    end

    # バンド名・メンバー名をまとめて入力し、Unit・UnitSnapshot（現在のラインナップ）・
    # SnapshotPerson を1回のsubmitで一括作成する簡易フォーム（issue #1596）。
    # データ構造・既存フローには手を加えず、入り口を追加するのみ。
    def quick_new
      @unit = Unit.new(quick_unit_params_for_new)
      @snapshot_date_prefill = params.dig(:unit, :snapshot_date).presence
      @snapshot_label_prefill = params.dig(:unit, :snapshot_label).presence
      @member_rows = quick_member_rows_for_new
      @duplicated_unit = Unit.with_discarded.find_by('key ILIKE ?', @unit.key) if @unit.key.present?
    end

    def quick_create
      @unit = Unit.new(quick_unit_params)
      member_rows = quick_member_rows

      ActiveRecord::Base.transaction do
        @unit.save!
        record_update_log(@unit, action: 'create')

        @unit_snapshot = @unit.unit_snapshots.create!(quick_snapshot_params.merge(current: true, active: true))
        record_update_log(@unit_snapshot, action: 'create')

        member_rows.each_with_index do |attrs, index|
          next if attrs[:person_name].blank?

          snapshot_person = @unit_snapshot.snapshot_people.create!(attrs.merge(sort_order: index))
          record_update_log(snapshot_person, action: 'create')
        end
      end

      redirect_to edit_admin_unit_path(@unit), notice: 'Unitを作成しました。'
    rescue ActiveRecord::RecordInvalid => e
      @unit.errors.merge!(e.record.errors) unless e.record.equal?(@unit)
      @member_rows = member_rows.map { |attrs| OpenStruct.new(attrs) }
      @member_rows << OpenStruct.new(person_name: '', part: 'vocal') if @member_rows.none? { |r| r.person_name.blank? }
      render :quick_new, status: :unprocessable_entity
    end

    def edit
      @unit_logs = @unit.unit_logs.order(:log_date)
      # ユニットページ本体・スナップショット一覧（Admin::UnitSnapshotsController#index）の
      # 表示順に合わせる
      @unit_snapshots = @unit.unit_snapshots.includes(snapshot_people: :person)
                             .order(past: :asc, current: :desc, snapshot_index: :asc)
      @unit.links.build # Build an empty link for the form
      @wiki_page_imports = @unit.wiki_page_imports.includes(:wikipage).order(updated_at: :desc)
      @update_logs = UpdateLog.for_unit(@unit)
                              .includes(:user)
                              .order(created_at: :desc)
                              .limit(50)
    end

    def create
      @unit = Unit.new(unit_params)

      if @unit.save
        record_update_log(@unit, action: 'create')
        convert_unit_submission(@unit, params[:unit_submission_id])
        redirect_to admin_units_path, notice: 'Unit created successfully.'
      else
        @unit.links.build if @unit.links.none?(&:new_record?)
        render :new, status: :unprocessable_entity
      end
    end

    def update
      pre_link_ids = @unit.links.pluck(:id)

      if @unit.update(unit_update_params)
        record_update_log(@unit, action: 'update')
        record_link_changes(@unit, pre_link_ids)
        redirect_to edit_admin_unit_path(@unit), notice: 'Unit updated successfully.'
      else
        @unit_logs = @unit.unit_logs.order(:log_date)
        # ユニットページ本体・スナップショット一覧（Admin::UnitSnapshotsController#index）の
        # 表示順に合わせる
        @unit_snapshots = @unit.unit_snapshots.includes(snapshot_people: :person)
                               .order(past: :asc, current: :desc, snapshot_index: :asc)
        @unit.links.build if @unit.links.none?(&:new_record?)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @unit.discard
      record_update_log(@unit, action: 'discard')
      redirect_to admin_units_path, notice: 'Unit deleted successfully.'
    end

    def undiscard
      @unit.undiscard
      record_update_log(@unit, action: 'undiscard')
      redirect_to admin_units_path, notice: 'Unit restored successfully.'
    end

    def change_key
      new_key = params[:new_key].to_s.strip

      if new_key.blank?
        redirect_to edit_admin_unit_path(@unit), alert: 'New key is required.'
        return
      end

      @unit.change_key!(new_key)
      record_update_log(@unit, action: 'change_key')
      redirect_to edit_admin_unit_path(@unit), notice: 'Key changed successfully.'
    rescue ActiveRecord::RecordNotUnique
      redirect_to edit_admin_unit_path(@unit), alert: 'That key is already in use.'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to edit_admin_unit_path(@unit), alert: e.message
    end

    def purge
      unless @unit.discarded?
        redirect_to admin_units_path(redirect_source: 'only'), alert: '論理削除済みのレコードのみ物理削除できます。'
        return
      end

      if Item.by_artist_key(@unit.key).exists?
        redirect_to admin_units_path(redirect_source: 'only'), alert: 'このキーはまだ作品から参照されているため物理削除できません。'
        return
      end

      if Unit.with_discarded.where(destination_key: @unit.key).exists?
        redirect_to admin_units_path(redirect_source: 'only'), alert: 'このキーはリダイレクト先として参照されているため物理削除できません。'
        return
      end

      # 実在のPersonに紐づくメンバー情報(unit_people)が残っている場合は物理削除できない。
      # person_id が nil のインライン仮メンバー情報のみの場合は destroy_all で道連れに削除する。
      if @unit.unit_people.where.not(person_id: nil).exists?
        redirect_to admin_units_path(redirect_source: 'only'), alert: '実在のPersonに紐づくメンバー情報が残っているため物理削除できません。'
        return
      end

      key_was = @unit.key
      destination_was = @unit.destination_key
      ActiveRecord::Base.transaction do
        @unit.unit_people.destroy_all
        @unit.destroy!
        UpdateLog.create!(
          user: current_user,
          action: 'purge',
          loggable_type: 'Unit',
          loggable_id: @unit.id,
          diff: { 'key' => [key_was, nil], 'destination_key' => [destination_was, nil] }
        )
      end
      redirect_to admin_units_path(redirect_source: 'only'), notice: 'リダイレクト元レコードを物理削除しました。'
    end

    def bulk_update_status
      ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
      status = params[:status].presence
      return redirect_back_or_to admin_units_path, alert: '項目が選択されていません' if ids.empty?
      return redirect_back_or_to admin_units_path, alert: 'Statusを選択してください' unless Unit.statuses.key?(status)

      count = 0
      Unit.with_discarded.where(id: ids).find_each do |unit|
        next if unit.status == status

        unit.update!(status: status)
        record_update_log(unit, action: 'update')
        count += 1
      end
      redirect_back_or_to admin_units_path, notice: "#{count}件のStatusを更新しました"
    end

    def search
      q = params[:q]
      scope = Unit.kept

      if q.present?
        scope = scope.where(
          'name ILIKE :q OR name_kana ILIKE :q OR key ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q',
          q: "%#{normalize_search_query(q)}%"
        )
      end

      @units = scope.limit(10).order(:name)

      render json: @units.map { |u| { id: u.id, name: u.name, name_kana: u.name_kana, key: u.key, destination_key: u.destination_key } }
    end

    private

    def set_unit
      @unit = Unit.with_discarded.find(params[:id])
    end

    def unit_params
      params.require(:unit).permit(:name, :name_kana, :key, :status, :unit_type, :old_key, :destination_key, :note,
                                   tag_index_ids: [],
                                   links_attributes: %i[id text url active sort_order _destroy],
                                   name_logs_attributes: %i[name name_kana],
                                   aliases_attributes: %i[name kana old_key hidden],
                                   activity_periods_attributes: %i[from to label])
    end

    # key はキー変更専用の操作でのみ変更可能(issue #57)。通常の update では受け付けない。
    def unit_update_params
      unit_params.except(:key)
    end

    def quick_unit_params
      quick_rename_nested_attributes_keys!
      params.require(:unit).permit(:name, :key, :unit_type, :status,
                                   activity_periods_attributes: %i[from to label],
                                   links_attributes: %i[text url])
    end

    # quick_new（GET）用。URL経由の事前入力に対応する（issue #1611, #1616）。quick_unit_params と異なり
    # params[:unit] が無い初期表示でも動くよう require ではなく緩く読み、enum に無い値は無視する。
    def quick_unit_params_for_new
      quick_rename_nested_attributes_keys!
      permitted = params[:unit]&.permit(:name, :key, :unit_type, :status,
                                        activity_periods_attributes: %i[from to label],
                                        links_attributes: %i[text url]) || {}
      permitted.delete(:unit_type) unless Unit.unit_types.key?(permitted[:unit_type])
      permitted.delete(:status) unless Unit.statuses.key?(permitted[:status])
      permitted
    end

    # unit-url スキルが生成する URL は `unit[members]` に揃えて `unit[activity_periods]` /
    # `unit[links]` という短いキー名を使う（issue #1616）。一方 accepts_nested_attributes_for が
    # 期待するキーは `activity_periods_attributes` / `links_attributes` なので、ここで読み替える。
    def quick_rename_nested_attributes_keys!
      return if params[:unit].blank?

      %w[activity_periods links].each do |key|
        value = params[:unit].delete(key)
        params[:unit]["#{key}_attributes"] = value if value.present?
      end
    end

    # quick_new（GET）用。空行を除去する quick_member_rows と異なり、入力欄の行として
    # そのまま表示するため空行も保持する。part が enum に無い値は無視する。
    def quick_member_rows_for_new
      raw_rows = params.dig(:unit, :members)
      return QUICK_CREATE_DEFAULT_PARTS.map { |part| OpenStruct.new(person_name: '', part: part, extra_profile: {}) } if raw_rows.blank?

      raw_rows.values.map do |row|
        permitted = row.permit(:person_name, :part, extra_profile: %i[birthday birth_year blood hometown])
        part = permitted[:part]
        part = nil unless SnapshotPerson.parts.key?(part)
        extra_profile = permitted[:extra_profile].is_a?(ActionController::Parameters) ? permitted[:extra_profile].to_h : {}
        OpenStruct.new(person_name: permitted[:person_name].to_s, part: part, extra_profile: extra_profile)
      end
    end

    def quick_snapshot_params
      params.require(:unit).permit(:snapshot_date, :snapshot_label).then do |p|
        { snapshot_date: p[:snapshot_date].presence, label: p[:snapshot_label].presence }
      end
    end

    # 空行（名前未入力）は保存時に無視する。既存の name_logs_attributes= 等と同じ考え方。
    # extra_profile（誕生日・生年・血液型・出身地の下書き。issue #1619）も受け取れるようにする
    # （issue #1620）。SnapshotPeopleController#snapshot_person_params と同じ考え方で、
    # 空文字は保存せず nil にする。
    def quick_member_rows
      raw_rows = params[:unit][:members]
      return [] if raw_rows.blank?

      raw_rows.values.map do |row|
        attrs = row.permit(:person_name, :part, extra_profile: %i[birthday birth_year blood hometown]).to_h.symbolize_keys
        attrs[:extra_profile] = attrs[:extra_profile].compact_blank.presence if attrs[:extra_profile].is_a?(Hash)
        attrs
      end
    end

    # 公開の投稿フォーム(UnitSubmission)からの「承認」導線。投稿内容を新規作成フォームの
    # 初期値として引き継ぐ（issue #1545）。key は投稿に含まれないため引き継がない。
    def prefill_from_unit_submission(unit, unit_submission_id)
      unit_submission = UnitSubmission.pending.find_by(id: unit_submission_id)
      return unless unit_submission

      unit.name = unit_submission.name
      unit.name_kana = unit_submission.name_kana
      unit.unit_type = unit_submission.unit_type
      unit.status = unit_submission.status
      unit_submission.links.each { |link| unit.links.build(text: link.text, url: link.url) }
      unit.note = unit_submission_note(unit_submission)
    end

    def unit_submission_note(unit_submission)
      lines = []
      lines << "[投稿者より] #{unit_submission.note}" if unit_submission.note.present?
      lines << "[連絡先] #{unit_submission.email}" if unit_submission.email.present?
      lines << '[本人・関係者からの投稿]' if unit_submission.is_related_person?
      lines.join("\n")
    end

    def convert_unit_submission(unit, unit_submission_id)
      unit_submission = UnitSubmission.pending.find_by(id: unit_submission_id)
      return unless unit_submission

      unit_submission.update!(submission_status: :converted, converted_unit: unit)
    end
  end
end

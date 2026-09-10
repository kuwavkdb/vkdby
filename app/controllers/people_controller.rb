# frozen_string_literal: true

class PeopleController < ApplicationController
  # 個人データ（parts/blood/hometown/status）で直接絞り込むため、タグ運用の同名グループは一覧の絞り込みUIから除外する
  PERSON_DATA_TAG_GROUP_NAMES = %w[パート 血液型 出身地 状況].freeze
  BLOOD_TYPES = %w[A B O AB Unknown].freeze

  def index
    load_tag_filter_groups
    load_selected_filters

    scope = build_scope
    @pagy, @people = pagy(scope, limit: 60)

    @person_data_filters = build_person_data_filters
  end

  def search
    q = normalize_search_query(params[:q].to_s.strip.first(100))
    if q.length < 2
      render json: []
      return
    end

    conn = ActiveRecord::Base.connection
    quoted_exact = conn.quote(q)
    quoted_prefix = conn.quote("#{q}%")
    people = Person.kept
                   .where('name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q', q: "%#{q}%")
                   .order(Arel.sql(<<~SQL.squish))
                     CASE
                       WHEN name = #{quoted_exact} OR name_kana = #{quoted_exact} THEN 0
                       WHEN name ILIKE #{quoted_prefix} OR name_kana ILIKE #{quoted_prefix} THEN 1
                       ELSE 2
                     END
                   SQL
                   .order(name_kana: :asc)
                   .limit(10)
                   .pluck(:name, :name_kana, :key)
                   .map { |name, name_kana, key| { name:, name_kana:, key: } }
    render json: people
  end

  def units
    person = Person.kept.find_by!(key: params[:key])
    unit_keys = person.snapshot_people
                      .joins(unit_snapshot: :unit)
                      .merge(Unit.kept)
                      .distinct
                      .pluck('units.key')
    render json: { unit_keys:, person_name: person.name }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Person not found' }, status: :not_found
  end

  def show
    @person = Person.kept.find_by!(key: params[:key])
    render json: @person
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Person not found' }, status: :not_found
  end

  private

  def base_scope
    @base_scope ||= Person.kept.where.not(key: [nil, ''])
  end

  def load_tag_filter_groups
    @filter_groups = IndexGroup.for_people.where.not(name: PERSON_DATA_TAG_GROUP_NAMES).includes(:tag_indices)
    all_tag_index_ids = @filter_groups.flat_map { |g| g.tag_indices.map(&:id) }
    @tag_person_counts = TagIndexItem.where(tag_index_id: all_tag_index_ids, indexable_type: 'Person').group(:tag_index_id).count
  end

  def load_selected_filters
    @selected_tag_ids = params[:tag_ids]&.to_unsafe_h&.transform_values(&:presence)&.compact || {}
    @selected_part = params[:part] if Person::AVAILABLE_PARTS.include?(params[:part])
    @selected_blood = params[:blood] if BLOOD_TYPES.include?(params[:blood])
    @selected_hometown = params[:hometown].presence
    @selected_status = params[:status] if Person.statuses.key?(params[:status])
  end

  def any_filter_selected?
    @selected_tag_ids.any? || @selected_part || @selected_blood || @selected_hometown || @selected_status
  end

  def build_scope
    scope = base_scope.order(updated_at: :desc)
    if params[:q].present?
      scope = scope.where(
        'people.name ILIKE :q OR people.name_kana ILIKE :q OR people.name_log::text ILIKE :q OR people.aliases::text ILIKE :q OR people.old_history ILIKE :q',
        q: "%#{normalize_search_query(params[:q])}%"
      )
    end

    @selected_tag_ids.each_value do |tag_id|
      scope = scope.where(id: Person.joins(:tag_indices).where(tag_indices: { id: tag_id }).select(:id))
    end
    scope = scope.where('parts @> ?::jsonb', [@selected_part].to_json) if @selected_part
    scope = scope.where(blood: @selected_blood) if @selected_blood
    scope = scope.where(hometown: @selected_hometown) if @selected_hometown
    scope = scope.where(status: @selected_status) if @selected_status

    any_filter_selected? ? scope.reorder(name_kana: :asc) : scope
  end

  def build_person_data_filters
    hometown_counts = base_scope.where.not(hometown: [nil, '']).group(:hometown).count.sort_by { |_, count| -count }

    [
      { param: :part, name: 'パート', selected: @selected_part,
        options: Person::AVAILABLE_PARTS.map { |p| { value: p, label: p.humanize, count: base_scope.where('parts @> ?::jsonb', [p].to_json).count } } },
      { param: :blood, name: '血液型', selected: @selected_blood,
        options: BLOOD_TYPES.map { |b| { value: b, label: b == 'Unknown' ? '不明' : b, count: base_scope.where(blood: b).count } } },
      { param: :hometown, name: '出身地', selected: @selected_hometown,
        options: hometown_counts.map { |h, c| { value: h, label: h, count: c } } },
      { param: :status, name: 'ステータス', selected: @selected_status,
        options: Person.statuses.keys.map { |s| { value: s, label: Person::STATUS_TRANSLATIONS[s], count: base_scope.where(status: s).count } } }
    ]
  end
end

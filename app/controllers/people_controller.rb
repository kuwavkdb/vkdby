# frozen_string_literal: true

class PeopleController < ApplicationController # rubocop:disable Metrics/ClassLength
  # 個人データ（parts/blood/hometown/status）で直接絞り込むため、タグ運用の同名グループは一覧の絞り込みUIから除外する
  PERSON_DATA_TAG_GROUP_NAMES = %w[パート 血液型 出身地 状況].freeze
  BLOOD_TYPES = Person::BLOOD_TYPES
  # 一覧の上に出す「個人ページのないメンバー」欄の上限（issue #1843）
  UNLINKED_MEMBERS_LIMIT = 30
  SUGGESTION_LIMIT = 10

  def index
    load_tag_filter_groups
    load_selected_filters

    scope = build_scope
    @pagy, @people = pagy(scope, limit: 60)
    @unlinked_members = load_unlinked_members

    @person_data_filters = build_person_data_filters
  end

  # 一覧ページの入力候補（JSON）。候補には名前そのものを並べるため、名前・よみがな系の列だけを探す。
  # セクション名やメンバー名でも探す matching_keyword（/search・/people?q=）とは、意図して範囲を分けている（issue #1841）。
  def search
    q = normalize_search_query(params[:q].to_s.strip.first(100))
    if q.length < 2
      render json: []
      return
    end

    conn = ActiveRecord::Base.connection
    quoted_exact = conn.quote(q)
    quoted_prefix = conn.quote(like_pattern(q, match: :prefix))
    people = Person.kept
                   .where('name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q', q: like_pattern(q))
                   .order(Arel.sql(<<~SQL.squish))
                     CASE
                       WHEN name = #{quoted_exact} OR name_kana = #{quoted_exact} THEN 0
                       WHEN name ILIKE #{quoted_prefix} OR name_kana ILIKE #{quoted_prefix} THEN 1
                       ELSE 2
                     END
                   SQL
                   .order(name_kana: :asc)
                   .limit(SUGGESTION_LIMIT)
                   .pluck(:name, :name_kana, :key)
                   .map { |name, name_kana, key| { name:, name_kana:, key: } }
    render json: people + unlinked_member_suggestions(q, SUGGESTION_LIMIT - people.size)
  end

  def units
    person = Person.kept.find_by!(key: params[:key])
    unit_keys = person.snapshot_people
                      .joins(unit_snapshot: :unit)
                      .merge(Unit.publicly_visible)
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

  # 個人ページのないメンバー（issue #1843）。検索語だけで探しているときの1ページ目にだけ出す。
  # パート・血液型・出身地・状況・タグの絞り込みは Person の項目なので、絞り込み中は出さない
  def load_unlinked_members
    return [] if params[:q].blank? || any_filter_selected? || @pagy.page > 1

    SnapshotPerson.unlinked_matching(normalize_search_query(params[:q]))
                  .includes(unit_snapshot: :unit)
                  .limit(UNLINKED_MEMBERS_LIMIT).load
  end

  # 入力候補の後ろに、個人ページのないメンバーを「名前（ユニット名）」として混ぜる（issue #1843）。
  # 個人ページがないため、url に所属ユニットのページのそのスナップショットを開いた状態を渡す
  def unlinked_member_suggestions(query, limit)
    return [] unless limit.positive?

    SnapshotPerson.unlinked_matching(query).includes(unit_snapshot: :unit).limit(limit).map do |member|
      unit = member.unit_snapshot.unit
      { name: member.name, name_kana: member.extra_profile_name_kana, unit_name: unit.name,
        url: profile_path(unit.key, anchor: "snapshot-#{member.unit_snapshot_id}") }
    end
  end

  def base_scope
    @base_scope ||= Person.for_index
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
    scope = scope.matching_keyword(like_pattern(normalize_search_query(params[:q]))) if params[:q].present?

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
    counts = PersonFilterCounts.call

    [
      { param: :part, name: 'パート', selected: @selected_part,
        options: Person::AVAILABLE_PARTS.map { |p| { value: p, label: p.humanize, count: counts[:part][p] || 0 } } },
      { param: :blood, name: '血液型', selected: @selected_blood,
        options: BLOOD_TYPES.map { |b| { value: b, label: b == 'Unknown' ? '不明' : b, count: counts[:blood][b] || 0 } } },
      { param: :hometown, name: '出身地', selected: @selected_hometown,
        options: counts[:hometown].map { |h, c| { value: h, label: h, count: c } } },
      { param: :status, name: 'ステータス', selected: @selected_status,
        options: Person.statuses.keys.map { |s| { value: s, label: Person::STATUS_TRANSLATIONS[s], count: counts[:status][s] || 0 } } }
    ]
  end
end

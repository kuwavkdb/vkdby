# frozen_string_literal: true

class UnitsController < ApplicationController
  def index
    @filter_groups = IndexGroup.for_units.includes(:tag_indices)
    all_tag_index_ids = @filter_groups.flat_map { |g| g.tag_indices.map(&:id) }
    @tag_unit_counts = TagIndexItem.where(tag_index_id: all_tag_index_ids, indexable_type: 'Unit')
                                   .group(:tag_index_id)
                                   .count

    scope = Unit.for_index.order(updated_at: :desc)
    scope = scope.matching_name_keyword(like_patterns(normalize_search_query(params[:q]))) if params[:q].present?
    @selected_tag_ids = params[:tag_ids]&.to_unsafe_h&.transform_values(&:presence)&.compact || {}
    if @selected_tag_ids.any?
      @selected_tag_ids.each_value do |tag_id|
        scope = scope.where(id: Unit.joins(:tag_indices).where(tag_indices: { id: tag_id }).select(:id))
      end
      scope = scope.reorder(name_kana: :asc)
    end

    # ビューの @units.any? で存在確認のクエリが別に走らないよう、ここで読み込んでおく（issue #1855）
    @pagy, @units = pagy(scope, limit: 60)
    @units = @units.load
    # meta description の「絞り込み後の件数/全体の件数」用（issue #1957）。絞り込んでいなければ件数は同じ
    @filtered = params[:q].present? || @selected_tag_ids.any?
    @total_unit_count = @filtered ? Unit.for_index.count : @pagy.count
  end

  # 一覧ページの入力候補（JSON）。候補には名前そのものを並べるため、名前・よみがな系の列だけを探す。
  # セクション名やメンバー名でも探す matching_keyword（/search）とは、意図して範囲を分けている（issue #1841、#1855）。
  def search
    q = normalize_search_query(params[:q].to_s.strip.first(100))
    if q.length < 2
      render json: []
      return
    end

    # ひらがなだけの検索語は、カタカナにした語でも探す（issue #2042）
    variants = SearchQuery.variants(q)
    relevance_order = Arel.sql(ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, { exact: variants, prefix: like_patterns(q, match: :prefix) }]))
      CASE
        WHEN name = ANY (ARRAY[:exact]) OR name_kana = ANY (ARRAY[:exact]) THEN 0
        WHEN name ILIKE ANY (ARRAY[:prefix]) OR name_kana ILIKE ANY (ARRAY[:prefix]) THEN 1
        ELSE 2
      END
    SQL
    units = Unit.publicly_visible.where('name ILIKE ANY (ARRAY[:q]) OR name_kana ILIKE ANY (ARRAY[:q])', q: like_patterns(q))
                .order(relevance_order)
                .order(name_kana: :asc)
                .limit(10)
                .pluck(:name, :name_kana, :key)
                .map { |name, name_kana, key| { name:, name_kana:, key: } }
    render json: units
  end

  def show
    @unit = Unit.publicly_visible.find_by!(key: params[:key])
    render json: @unit
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Unit not found' }, status: :not_found
  end
end

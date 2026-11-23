# frozen_string_literal: true

class BasicAttributesComponent < ViewComponent::Base
  def initialize(resource:)
    @resource = resource
  end

  def render?
    attributes_present?
  end

  def visible_tag_indices
    @visible_tag_indices ||= @resource.tag_indices.group_active.order(:name).to_a
  end

  # ステータスが「移行」のユニットの後継ユニット（issue #1996）
  def transitioned_unit
    return unless @resource.is_a?(Unit)

    @transitioned_unit ||= @resource.visible_transitioned_unit
  end

  # このユニットを後継として「移行」した前身のユニット（issue #1996）
  def predecessor_units
    return [] unless @resource.is_a?(Unit)

    @predecessor_units ||= @resource.visible_predecessor_units.to_a
  end

  # 誕生年のリンク先。年別ページがない1969年以前は、個人一覧の誕生年の絞り込み（issue #2094）へ向ける（issue #2101）
  def birth_year_path
    year = @resource.birth_year
    DatePageRange.cover?(year) ? yearly_path(year:) : people_path(birth_year: year)
  end

  private

  def attributes_present?
    tags_present = visible_tag_indices.present?

    if @resource.is_a?(Person)
      tags_present || @resource.birthday.present? || @resource.blood.present? ||
        @resource.hometown.present? || @resource.status.present? || @resource.parts.present?
    elsif @resource.is_a?(Unit)
      tags_present || @resource.unit_type.present? || @resource.status.present?
    else
      false
    end
  end
end

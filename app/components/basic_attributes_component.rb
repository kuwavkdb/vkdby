# frozen_string_literal: true

class BasicAttributesComponent < ViewComponent::Base
  def initialize(resource:)
    @resource = resource
  end

  def render?
    attributes_present?
  end

  private

  def attributes_present?
    tags_present = @resource.tag_indices.present?

    if @resource.is_a?(Person)
      tags_present || @resource.birthday.present? || @resource.blood.present? || @resource.hometown.present? || @resource.status.present? || @resource.parts.present?
    elsif @resource.is_a?(Unit)
      tags_present || @resource.unit_type.present? || @resource.status.present?
    else
      false
    end
  end
end

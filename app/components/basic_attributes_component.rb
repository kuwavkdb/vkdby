class BasicAttributesComponent < ViewComponent::Base
  def initialize(resource:)
    @resource = resource
  end

  def render?
    attributes_present?
  end

  private

  def attributes_present?
    if @resource.is_a?(Person)
      @resource.birthday.present? || @resource.blood.present? || @resource.hometown.present? || @resource.status.present?
    elsif @resource.is_a?(Unit)
      @resource.unit_type.present? || @resource.status.present?
    else
      false
    end
  end
end

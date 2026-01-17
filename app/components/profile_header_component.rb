class ProfileHeaderComponent < ViewComponent::Base
  def initialize(resource:)
    @resource = resource
  end

  private

  def bg_class
    @resource.is_a?(Unit) ? "bg-unit" : "bg-person"
  end

  def type_label
    if @resource.is_a?(Unit)
      @resource.unit_type.present? ? @resource.unit_type.upcase : "UNIT"
    else
      "PERSON"
    end
  end

  def name
    @resource.name
  end

  def name_kana
    @resource.name_kana
  end
end

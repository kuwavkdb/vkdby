class ManagementInformationComponentPreview < ViewComponent::Preview
  layout "component_preview"
  def default
    resource = Person.new(key: "current_key", old_key: "old_key_value")
    render(ManagementInformationComponent.new(resource: resource))
  end

  def key_only
    resource = Unit.new(key: "unit_key")
    render(ManagementInformationComponent.new(resource: resource))
  end
end

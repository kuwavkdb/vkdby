class BasicAttributesComponentPreview < ViewComponent::Preview
  layout "component_preview"
  def person
    person = Person.new(
      name: "Person Name",
      birthday: Date.new(1990, 1, 1),
      blood: "A",
      hometown: "Tokyo",
      status: "active"
    )
    render(BasicAttributesComponent.new(resource: person))
  end

  def unit
    unit = Unit.new(
      name: "Unit Name",
      unit_type: "band",
      status: "active"
    )
    render(BasicAttributesComponent.new(resource: unit))
  end
end

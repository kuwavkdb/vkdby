# frozen_string_literal: true

class ProfileHeaderComponentPreview < ViewComponent::Preview
  layout 'component_preview'
  def person
    person = Person.new(name: 'HYDE', name_kana: 'はいど')
    render(ProfileHeaderComponent.new(resource: person))
  end

  def unit
    unit = Unit.new(name: "L'Arc~en~Ciel", unit_type: 'band')
    render(ProfileHeaderComponent.new(resource: unit))
  end
end

# frozen_string_literal: true

class UnitMembersComponentPreview < ViewComponent::Preview
  layout 'component_preview'
  def default
    active_member = UnitPerson.new(
      person: Person.new(name: 'Active Member', key: 'active'),
      part: 'vocal',
      status: 'active'
    )
    past_member = UnitPerson.new(
      person: Person.new(name: 'Past Member', key: 'past'),
      part: 'bass',
      status: 'left'
    )

    unit = Unit.new(name: 'Unit Name')

    render(UnitMembersComponent.new(
             unit: unit,
             active_members: [active_member],
             past_members: [past_member]
           ))
  end

  def active_only
    active_member = UnitPerson.new(
      person: Person.new(name: 'Active Member', key: 'active'),
      part: 'vocal',
      status: 'active'
    )
    unit = Unit.new(name: 'Unit Name')

    render(UnitMembersComponent.new(
             unit: unit,
             active_members: [active_member],
             past_members: []
           ))
  end
end

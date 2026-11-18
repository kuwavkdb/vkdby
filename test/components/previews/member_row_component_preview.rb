# frozen_string_literal: true

class MemberRowComponentPreview < ViewComponent::Preview
  layout 'component_preview'
  def active_member
    person = Person.new(name: 'Active Member', key: 'active_person')
    member = UnitPerson.new(
      person: person,
      part: 'vocal',
      status: 'active',
      sns: ['@vocalist']
    )
    render(MemberRowComponent.new(member: member))
  end

  def past_member
    person = Person.new(name: 'Past Person', key: 'past_person')
    member = UnitPerson.new(
      person: person,
      part: 'bass',
      status: 'left',
      sns: nil
    )
    render(MemberRowComponent.new(member: member))
  end
end

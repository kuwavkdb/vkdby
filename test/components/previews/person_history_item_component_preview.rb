# frozen_string_literal: true

class PersonHistoryItemComponentPreview < ViewComponent::Preview
  layout 'component_preview'

  def default
    person = Person.new(name: 'Person Name', key: 'person_key')
    unit = Unit.new(name: 'Unit Name', key: 'unit_key')
    log = PersonLog.new(log_date: Date.today, phenomenon: 'join', person: person, unit: unit, part: 'vocal')

    render(PersonHistoryItemComponent.new(log: log))
  end

  def with_rename
    Person.new(name: 'New Name', key: 'person_key')
    unit = Unit.new(name: 'Unit Name', key: 'unit_key')
    log = PersonLog.new(log_date: Date.today, phenomenon: 'rename', name: 'Old Name', unit: unit)

    render(PersonHistoryItemComponent.new(log: log))
  end

  def with_text
    person = Person.new(name: 'Person Name', key: 'person_key')
    unit = Unit.new(name: 'Unit Name', key: 'unit_key')
    log = PersonLog.new(log_date: Date.today, text: 'Some text log', phenomenon: 'stay', person: person, unit: unit)

    render(PersonHistoryItemComponent.new(log: log))
  end

  def with_alias
    person = Person.new(name: 'Person Name', key: 'person_key')
    unit = Unit.new(name: 'Unit Name', key: 'unit_key')
    log = PersonLog.new(log_date: Date.today, phenomenon: 'leave', phenomenon_alias: '卒業', person: person, unit: unit)

    render(PersonHistoryItemComponent.new(log: log))
  end
end

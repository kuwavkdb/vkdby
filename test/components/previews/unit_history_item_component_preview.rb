# frozen_string_literal: true

class UnitHistoryItemComponentPreview < ViewComponent::Preview
  layout 'component_preview'

  def unit_log
    Unit.new(name: 'Unit Name', key: 'unit_key')
    log = UnitLog.new(log_date: Date.today, phenomenon: 'first_live')

    render(UnitHistoryItemComponent.new(log: log))
  end

  def person_log_join
    unit = Unit.new(name: 'Unit Name', key: 'unit_key')
    person = Person.new(name: 'Member Name', key: 'member_key')
    log = PersonLog.new(log_date: Date.today, phenomenon: 'join', person: person, unit: unit, part: 'guitar')

    render(UnitHistoryItemComponent.new(log: log))
  end

  def person_log_leave
    unit = Unit.new(name: 'Unit Name', key: 'unit_key')
    person = Person.new(name: 'Member Name', key: 'member_key')
    log = PersonLog.new(log_date: Date.today, phenomenon: 'leave', person: person, unit: unit)

    render(UnitHistoryItemComponent.new(log: log))
  end

  def with_alias
    Unit.new(name: 'Unit Name', key: 'unit_key')
    log = UnitLog.new(log_date: Date.today, phenomenon: 'finish', phenomenon_alias: '集結')

    render(UnitHistoryItemComponent.new(log: log))
  end
end

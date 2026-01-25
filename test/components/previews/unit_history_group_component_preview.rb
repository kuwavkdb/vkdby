# frozen_string_literal: true

class UnitHistoryGroupComponentPreview < ViewComponent::Preview
  # @label Default
  def default
    mock_unit = Unit.new(id: 1, name: 'Unit Name', key: 'unit_key')
    mock_person = Person.new(id: 1, name: 'Person Name', key: 'person_key')

    date = '2009-03-14'

    logs = [
      UnitLog.new(
        id: 1,
        unit: mock_unit,
        log_date: Date.parse(date),
        phenomenon: :announcement,
        text: nil
      ),
      PersonLog.new(
        id: 1,
        person: mock_person,
        unit: mock_unit,
        log_date: date,
        phenomenon: :join,
        name: 'Log Name'
      ),
      PersonLog.new(
        id: 2,
        person: mock_person,
        unit: mock_unit,
        log_date: date,
        phenomenon: :original_member,
        name: nil
      )
    ]

    render(UnitHistoryGroupComponent.new(date: date, logs: logs))
  end
end

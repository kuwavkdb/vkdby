# frozen_string_literal: true

class UnitHistoryGroupComponentPreview < ViewComponent::Preview
  # @label Default
  def default
    mock_unit = Unit.new(id: 1, name: 'Unit Name', key: 'unit_key')

    date = '2009-03-14'

    logs = [
      UnitLog.new(
        id: 1,
        unit: mock_unit,
        log_date: Date.parse(date),
        phenomenon: :announcement,
        text: nil
      )
    ]

    render(UnitHistoryGroupComponent.new(date: date, logs: logs))
  end
end

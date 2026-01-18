class UnitHistoryComponentPreview < ViewComponent::Preview
  layout "component_preview"

  def default
    unit = Unit.new(name: "Unit Name", key: "unit_key")
    logs = [
      UnitLog.new(log_date: Date.today, phenomenon: "first_live"),
      UnitLog.new(log_date: Date.today - 3.months, text: "Some unit event", phenomenon: "finish")
    ]
    render(UnitHistoryComponent.new(unit: unit, logs: logs))
  end

  def with_member_logs
    unit = Unit.new(name: "My Unit", key: "my_unit")
    person = Person.new(name: "Member Name", key: "member_key")

    logs = [
      PersonLog.new(log_date: Date.today, status: "join", person: person, unit: unit, part: "guitar"),
      PersonLog.new(log_date: Date.today - 1.year, status: "leave", person: person, unit: unit, part: nil),
      UnitLog.new(log_date: Date.today - 2.years, phenomenon: "form")
    ]
    render(UnitHistoryComponent.new(unit: unit, logs: logs))
  end
end

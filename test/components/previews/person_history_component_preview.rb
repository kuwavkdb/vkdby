class PersonHistoryComponentPreview < ViewComponent::Preview
  layout "component_preview"

  def default
    person = Person.new(name: "Person Name", key: "person_key")
    unit = Unit.new(name: "Unit Name", key: "unit_key")

    logs = [
      PersonLog.new(log_date: Date.today, status: "join", person: person, unit: unit, part: "vocal"),
      PersonLog.new(log_date: Date.today - 1.year, status: "stay", person: person, unit: unit),
      PersonLog.new(log_date: Date.today - 2.years, text: "Some text log", status: "stay", person: person, unit: unit),
      PersonLog.new(log_date: Date.today - 3.years, status: "rename", name: "Old Person Name", unit: unit),
      PersonLog.new(log_date: Date.today - 4.years, status: "rename", name: "Older Person Name", unit_name: "Old Unit Name")
    ]
    render(PersonHistoryComponent.new(person: person, logs: logs))
  end
end

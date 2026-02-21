# frozen_string_literal: true

class HistoryRowComponentPreview < ViewComponent::Preview
  layout 'component_preview'

  def default
    items = [
      { unit_name: 'Band A' },
      { unit_name: 'Band B' },
      { unit_name: 'Band C' }
    ]
    render(HistoryRowComponent.with_collection([items]))
  end

  def with_details
    items = [
      { unit_name: 'Band A', part_and_name: 'Vo. Takuya', notes: ['Support'] },
      { unit_name: 'Band B', part_and_name: 'Gt. Ken' }
    ]
    render(HistoryRowComponent.with_collection([items]))
  end

  def with_links
    items = [
      { unit_name: 'Current Band', old_key: 'current_band' },
      { unit_name: 'External Band', external_url: 'https://example.com' }
    ]
    render(HistoryRowComponent.with_collection([items]))
  end

  def with_temp_status
    items = [
      { unit_name: 'Active Band' },
      { unit_name: 'Temp/Unknown Band', is_temp: true }
    ]
    render(HistoryRowComponent.with_collection([items]))
  end

  def complex_example
    items = [
      { unit_name: 'Band A', old_key: 'band_a', part_and_name: 'Vo. 太郎' },
      { unit_name: 'Band B', is_temp: true, notes: ['Guest'] },
      { unit_name: 'Band C', external_url: 'https://example.com', part_and_name: 'Gt. 次郎', notes: ['Support', 'Tour only'] }
    ]
    render(HistoryRowComponent.with_collection([items]))
  end
end

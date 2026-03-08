# frozen_string_literal: true

module Admin
  module BaseHelper
    # diff の値をフィールド名に応じて人間が読める形式に変換する
    def resolve_diff_value(field, value)
      return nil if value.blank?

      case field
      when 'person_id'
        name = Person.find_by(id: value)&.name
        name ? "#{name} (#{value})" : value.to_s
      when 'unit_snapshot_id'
        label = UnitSnapshot.find_by(id: value)&.display_label
        label ? "#{label} (#{value})" : value.to_s
      else
        value.to_s
      end
    end
  end
end

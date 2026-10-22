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

    # リンク欄のタイトル補完に使う外部サイトの一覧（JSON）
    def link_title_suggest_sites_json
      ExternalSite.link_title_suggestions.to_json
    end

    # 外部サイトに登録しなくてもタイトルを補完できるサービスの対応表（JSON）
    def link_title_suggest_builtins_json
      ExternalSite::BUILTIN_LINK_TITLES.to_json
    end
  end
end

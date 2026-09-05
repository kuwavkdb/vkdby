# frozen_string_literal: true

module SectionsHelper
  # Section（Unit/Person/CustomPage付随セクション）の編集画面から、紐づく
  # sectionable（親レコード）の編集画面へ戻るためのパスを組み立てる。
  def sectionable_path(sectionable)
    case sectionable
    when Unit       then edit_admin_unit_path(sectionable)
    when Person     then edit_admin_person_path(sectionable)
    when CustomPage then edit_admin_custom_page_path(sectionable)
    when Item       then edit_admin_item_path(sectionable)
    end
  end

  def sectionable_label(sectionable)
    case sectionable
    when Unit       then "ユニット「#{sectionable.name}」の編集へ"
    when Person     then "人物「#{sectionable.name}」の編集へ"
    when CustomPage then "カスタムページ「#{sectionable.title}」の編集へ"
    when Item       then "アイテム「#{sectionable.title}」の編集へ"
    end
  end
end

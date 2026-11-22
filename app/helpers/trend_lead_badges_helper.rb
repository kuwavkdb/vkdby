# frozen_string_literal: true

# 一覧（動向の一覧・日付別・月別・年別・会場ページなど）で、動向の件名の前に出すバッジ（issue #2092）。
# 個人名を出すかどうかの判定は TrendsHelper#trend_show_person_badge_in_title?（動向の詳細ページと同じ）
module TrendLeadBadgesHelper
  # 一覧で件名の前に出す、ユニット・個人のページへのリンクのバッジ
  LEAD_BADGE_LINK_CLASS = 'inline-block px-2 py-0.5 rounded text-sm font-semibold bg-indigo-50 text-indigo-600 ' \
                          'hover:bg-indigo-100 dark:bg-indigo-900 dark:text-indigo-200 dark:hover:bg-indigo-800 ' \
                          'transition-colors mr-1 border border-indigo-200 dark:border-indigo-700'

  # 一覧（動向の一覧・日付別・月別・年別・会場ページなど）で件名の前に出すバッジ（issue #2092）。
  # 詳細ページと同じ判定（trend_show_person_badge_in_title?）で個人名を出す動向は、ユニット名の代わりに個人名を出す。
  # それ以外はユニット名。ページのある（公開中の）ユニット・個人はそのページへのリンク、無いものは名前だけのバッジにする。
  # current_unit_name: true なら、ユニット名は動向登録時点の名前ではなく今の名前を使う（日付別・月別・年別の従来の表示）
  def trend_lead_badges(trend, related_units: {}, related_people: {}, link_class: LEAD_BADGE_LINK_CLASS,
                        current_unit_name: false)
    badges = if trend_show_person_badge_in_title?(trend)
               trend_person_lead_badges(trend, related_people || {}, link_class)
             else
               trend_unit_lead_badges(trend, related_units || {}, link_class, current_unit_name)
             end
    safe_join(badges, ' ')
  end

  private

  def trend_person_lead_badges(trend, related_people, link_class)
    (trend.people || []).filter_map do |person_data|
      person = related_people[person_data['person_id']]
      name = trend_person_display_name(person_data, person)
      if person&.key.present?
        link_to name, profile_path(person.key), class: link_class
      elsif name.present?
        unit_name_badge(name)
      end
    end
  end

  def trend_unit_lead_badges(trend, related_units, link_class, current_unit_name)
    (trend.units || []).filter_map do |unit_data|
      unit = related_units[unit_data['unit_id']]
      name = current_unit_name && unit ? unit.name : trend_unit_display_name(unit_data, unit)
      if unit&.key.present?
        link_to name, profile_path(unit.key), class: link_class
      elsif name.present?
        unit_name_badge(name)
      end
    end
  end
end

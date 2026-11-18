# frozen_string_literal: true

class MemberRowComponent < ViewComponent::Base
  include WikiLinkHelper
  include SnsIconHelper
  with_collection_parameter :member

  # admin_unit_id: スナップショットメンバー（SnapshotPerson）の行で管理者に編集リンクを出す
  # ときに、そのスナップショットが属するユニットのidを渡す（issue #1761）。nilなら出さない。
  # 個人（Person）と紐づいたメンバーは経歴・プロフィールを個人側で編集する（スナップショット
  # メンバー編集画面では編集できない、issue #1619）ため、個人の編集画面へのリンクも並べて出す
  def initialize(member:, admin_unit_id: nil)
    @member = member
    @admin_unit_id = admin_unit_id
  end

  # 表示するSNSアカウント。空の行と、行頭が "//" または "#" のコメント行（issue #1854）は除く
  def visible_sns_accounts
    return [] unless @member.sns.is_a?(Array)

    @member.sns.reject { |account| account.blank? || SnsInfoIcon.commented_out?(account) }
  end

  # @member.sns の1要素（"@handle"形式、またはURL）からアイコン種別を判定する。
  # "@"始まりは常にX(Twitter)アカウントの記法として扱う（{{member}}プラグイン記法、
  # app/helpers/application_helper.rb参照）。それ以外はURLとしてSnsInfoIconで判定し、
  # SNSとして判定できない場合（公式サイト等）はnil（汎用の外部リンクアイコンにフォールバック）
  def sns_icon_for(sns_account)
    return :x if sns_account.start_with?('@')

    SnsInfoIcon.icon_for_url(sns_account)
  end

  def sns_url_for(sns_account)
    SnsInfoIcon.url_for_account(sns_account)
  end

  # パートの表示名。別名（part_alias、"Vocal&Guitar" など先頭だけ大文字の表記）に合わせて
  # 先頭だけ大文字にする。DJ・etc. は Person.part_label の特別な表記にする（issue #1939, #2039）
  def part_label
    Person.part_label(@member.part)
  end

  private

  def edit_path
    return unless admin_links?

    edit_admin_unit_unit_snapshot_snapshot_person_path(@admin_unit_id, @member.unit_snapshot_id, @member)
  end

  def person_edit_path
    return unless admin_links? && @member.person

    edit_admin_person_path(@member.person)
  end

  def admin_links?
    @admin_unit_id.present? && @member.is_a?(SnapshotPerson)
  end

  def admin_link_classes
    'text-xs font-medium text-zinc-500 dark:text-zinc-400 hover:text-indigo-600 dark:hover:text-amber-400 ' \
      'rounded transition-colors focus:outline-none focus-visible:outline focus-visible:outline-2 ' \
      'focus-visible:outline-offset-2 focus-visible:outline-indigo-600 dark:focus-visible:outline-amber-400'
  end

  # 個人と紐づいたメンバーは、ステータスから状態の行を補った経歴を出す（issue #1992）。
  # どちらも経歴が「→」で終わっていれば「活動状況不明」の行を足す（issue #1939）
  def person_history_items
    if @member.person&.old_history.present?
      @member.person.history_items_with_status
    elsif @member.inline_history.present?
      @member.history_items_with_unknown(@member.parse_inline_history, @member.inline_history)
    else
      []
    end
  end
end

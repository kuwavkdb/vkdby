# frozen_string_literal: true

class MemberRowComponent < ViewComponent::Base
  include WikiLinkHelper
  include SnsIconHelper
  with_collection_parameter :member

  # admin_unit_id: スナップショットメンバー（SnapshotPerson）の行で管理者に編集リンクを出す
  # ときに、そのスナップショットが属するユニットのidを渡す（issue #1761）。nilなら出さない。
  # 個人（Person）と紐づいたメンバーは経歴・プロフィールを個人側で編集する（スナップショット
  # メンバー編集画面では編集できない、issue #1619）ため、個人の編集画面へのリンクも並べて出す
  def initialize(member:, hide_active: false, hide_left: false, hide_status: false, admin_unit_id: nil)
    @member = member
    @hide_active = hide_active
    @hide_left = hide_left
    @hide_status = hide_status
    @admin_unit_id = admin_unit_id
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

  def status_classes
    base_classes = 'text-[0.65rem] font-black uppercase px-2 py-0.5 rounded-md'
    color_classes = case @member.status
                    when 'active'
                      'bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-400'
                    when 'left'
                      'bg-rose-100 dark:bg-rose-900/40 text-rose-700 dark:text-rose-400'
                    when 'pre'
                      'bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-400'
                    when 'pending'
                      'bg-sky-100 dark:bg-sky-900/40 text-sky-700 dark:text-sky-400'
                    else
                      'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300'
                    end
    "#{base_classes} #{color_classes}"
  end

  def show_status?
    return false if @hide_status
    return false if @hide_active && @member.status == 'active'
    return false if @hide_left && @member.status == 'left'

    true
  end

  def person_history_items
    if @member.person&.old_history.present?
      @member.person.parse_old_history
    elsif @member.inline_history.present?
      @member.parse_inline_history
    else
      []
    end
  end
end

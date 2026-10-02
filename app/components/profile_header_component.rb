# frozen_string_literal: true

class ProfileHeaderComponent < ViewComponent::Base
  def initialize(resource:)
    @resource = resource
  end

  private

  def bg_class
    if @resource.is_a?(Unit)
      'bg-gradient-to-br from-blue-950 via-blue-900 to-blue-800'
    else
      'bg-gradient-to-br from-rose-950 via-rose-900 to-rose-800'
    end
  end

  def name
    @resource.name
  end

  def name_kana
    @resource.name_kana
  end

  # 名前とヨミガナが同じ文字列ならルビは冗長なので出さない
  def show_kana?(text, kana)
    kana.present? && kana.strip != text.to_s.strip
  end

  def display_aliases
    @resource.aliases.reject { |a| a.name.blank? || a.hidden }
  end

  def edit_url
    if @resource.is_a?(Person)
      helpers.edit_admin_person_path(@resource)
    elsif @resource.is_a?(Unit)
      helpers.edit_admin_unit_path(@resource)
    end
  end
end

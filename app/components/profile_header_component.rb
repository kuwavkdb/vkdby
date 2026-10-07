# frozen_string_literal: true

class ProfileHeaderComponent < ViewComponent::Base
  def initialize(resource:)
    @resource = resource
  end

  private

  def bg_class
    case @resource
    when Unit
      'bg-gradient-to-br from-blue-950 via-blue-900 to-blue-800'
    when Venue
      # 会場（issue #1691）。unit（青）・person（赤）のトークンと区別できる色にする
      'bg-gradient-to-br from-teal-950 via-teal-900 to-teal-800'
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

  def show_kana?(text, kana)
    helpers.show_kana?(text, kana)
  end

  def display_aliases
    @resource.aliases.reject { |a| a.name.blank? || a.hidden }
  end

  def edit_url
    case @resource
    when Person then helpers.edit_admin_person_path(@resource)
    when Unit then helpers.edit_admin_unit_path(@resource)
    when Venue then helpers.edit_admin_venue_path(@resource)
    end
  end
end

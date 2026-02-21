# frozen_string_literal: true

class UnitCardComponentPreview < ViewComponent::Preview
  layout 'component_preview'

  # 基本（名前のみ）
  def default
    unit = Unit.new(name: 'L\'Arc～en～Ciel', key: 'larc-en-ciel', unit_type: :band)
    render(UnitCardComponent.new(unit: unit))
  end

  # 読みがなあり
  def with_kana
    unit = Unit.new(name: 'L\'Arc～en～Ciel', name_kana: 'らるくあんしえる', key: 'larc-en-ciel', unit_type: :band)
    render(UnitCardComponent.new(unit: unit))
  end

  # 活動時期あり
  def with_activity_period
    unit = Unit.new(name: 'L\'Arc～en～Ciel', name_kana: 'らるくあんしえる', key: 'larc-en-ciel',
                    unit_type: :band, activity_period: [{ 'from' => '1991/02/**', 'to' => nil }])
    render(UnitCardComponent.new(unit: unit))
  end

  # 更新日表示あり（/units インデックス向け）
  def with_details
    unit = Unit.new(name: 'L\'Arc～en～Ciel', name_kana: 'らるくあんしえる', key: 'larc-en-ciel',
                    unit_type: :band, activity_period: [{ 'from' => '1991/02/**', 'to' => nil }],
                    updated_at: Time.current)
    render(UnitCardComponent.new(unit: unit, show_details: true))
  end
end

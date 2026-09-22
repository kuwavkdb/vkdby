# frozen_string_literal: true

class LinksComponent < ViewComponent::Base
  include SnsIconHelper

  # sns_info の platform 値とアイコン種別（アイコンSVGの切り替えに使うキー）の対応
  PLATFORM_ICONS = SnsInfoIcon::PLATFORM_ICONS

  def initialize(links:)
    @links = links
  end

  def render?
    @links.present?
  end

  # リンクの種類に応じたアイコン種別。SNSとして判定できないリンク（公式サイト等）はnil
  # （呼び出し側で汎用の外部リンクアイコンにフォールバックする）
  def link_icon(link)
    PLATFORM_ICONS[link.sns_info&.[](:platform)]
  end
end

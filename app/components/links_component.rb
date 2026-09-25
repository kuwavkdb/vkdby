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

  # アイコンを常にサービスのブランドカラーで表示するためのクラス（issue #1683）。
  # aria-hidden な装飾アイコン（サービス名は別途 sr-only テキストで伝わる）なので、
  # テキストのコントラスト基準（WCAG AA 4.5:1）は適用対象外。Spotifyのみ、その基準では
  # 満たせない本来の公式カラー（#1DB954）に任意値記法で近づけている。他は基準を満たす
  # 範囲でブランドカラーに寄せたTailwindのシェード。該当なし（汎用リンク）は共通の
  # indigo/amber-400 のまま。
  ICON_COLORS = {
    x: 'text-zinc-900 dark:text-zinc-300',
    instagram: 'text-pink-700 dark:text-pink-500',
    youtube: 'text-red-600 dark:text-red-500',
    tiktok: 'text-zinc-900 dark:text-white',
    spotify: 'text-[#1DB954] dark:text-green-500'
  }.freeze

  def icon_color(icon)
    ICON_COLORS[icon] || 'text-indigo-600 dark:text-amber-400'
  end
end

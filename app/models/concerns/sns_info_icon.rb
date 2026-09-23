# frozen_string_literal: true

# Link#sns_info の platform 文字列とアイコン種別（アイコンSVGの切り替えに使うキー、
# SnsIconHelper#sns_icon が受け取るシンボル）の対応。
# LinksComponent（Linkレコード経由、issue #1627）と
# MemberRowComponent（UnitPerson#sns等のURL文字列経由、issue #1648）の両方で使う。
module SnsInfoIcon
  PLATFORM_ICONS = {
    'Twitter' => :x,
    'Instagram' => :instagram,
    'YouTube' => :youtube,
    'TikTok' => :tiktok,
    'Spotify' => :spotify
  }.freeze

  module_function

  # URL文字列からアイコン種別を判定する。SNSとして判定できない場合はnil
  # （呼び出し側で汎用の外部リンクアイコンにフォールバックする）
  def icon_for_url(url)
    PLATFORM_ICONS[Link.new(url: url).sns_info&.[](:platform)]
  end
end

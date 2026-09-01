# frozen_string_literal: true

# 詳細・一覧ページのヘッダー右上に表示する管理者向けアクションリンク（Edit / Add など）。
# items/trends の show・index や ProfileHeaderComponent（Unit/Person）で共通利用する。
class HeaderActionLinkComponent < ViewComponent::Base
  THEMES = {
    # amber系ヘッダー（items/trends の show・index）向け
    amber: {
      text: 'text-amber-900/80 hover:text-amber-900',
      border: 'border-amber-900/20',
      focus_outline: 'focus-visible:outline-amber-900'
    },
    # 濃色ヘッダー（ProfileHeaderComponent）向け
    light: {
      text: 'text-white/80 hover:text-white',
      border: 'border-white/20',
      focus_outline: 'focus-visible:outline-white'
    }
  }.freeze

  def initialize(label:, url:, visible: true, theme: :amber)
    super()
    @label = label
    @url = url
    @visible = visible
    @theme = THEMES.fetch(theme)
  end

  def render?
    @visible
  end

  def link_classes
    [
      'px-3 py-1 bg-white/10 hover:bg-white/20 text-xs font-bold rounded backdrop-blur-sm transition',
      'border', @theme[:border], @theme[:text],
      'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2', @theme[:focus_outline]
    ].join(' ')
  end
end

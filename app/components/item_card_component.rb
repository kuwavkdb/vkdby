# frozen_string_literal: true

class ItemCardComponent < ViewComponent::Base
  include ItemsHelper

  MANY_ARTISTS_THRESHOLD = 8

  def initialize(item_card:)
    super()
    @item = item_card
  end

  def render?
    @item.present?
  end

  # アーティスト数がこの閾値を超える場合のみ、タグ表示エリアの高さを固定してフェードアウト表示にする
  def many_artists?
    @item.artists.size > MANY_ARTISTS_THRESHOLD
  end
end

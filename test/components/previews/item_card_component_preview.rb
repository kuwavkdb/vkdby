# frozen_string_literal: true

class ItemCardComponentPreview < ViewComponent::Preview
  layout 'component_preview'

  def with_image
    item = Item.new(
      id: 1,
      title: 'lynch. 20TH ANNIVERSARY XX FINAL ACT 「ALL THIS WE\'LL GIVE YOU」25.12.28 TOKYO GARDEN THEATER[数量限定盤] - lynch. [Blu-ray]',
      release_date: Date.new(2026, 4, 22),
      image_url: 'https://m.media-amazon.com/images/I/51Z1Z1Z1Z1L._SL160_.jpg',
      link_url: 'https://www.amazon.co.jp/exec/obidos/ASIN/B0EXAMPLE/vkdb07-22/',
      artists: [
        { 'name' => 'lynch.', 'old_key' => '%A5%EA%A5%F3%A5%C1' }
      ]
    )

    render(ItemCardComponent.new(item_card: item))
  end

  def without_image
    item = Item.new(
      id: 2,
      title: '【特典付】DIR EN GREY MORTAL DOWNER 【完全生産限定盤】(2CD+Blu-ray)【早期予約特典:オリジナルトレーディングカード+特典:ポストカード】',
      release_date: Date.new(2026, 4, 8),
      image_url: nil,
      link_url: 'https://www.amazon.co.jp/exec/obidos/ASIN/B0EXAMPLE2/vkdb07-22/',
      artists: [
        { 'name' => 'DIR EN GREY', 'old_key' => '%A5%C7%A5%A3%A5%EB%A5%A2%A5%F3%A5%B0%A5%EC%A5%A4' }
      ]
    )

    render(ItemCardComponent.new(item_card: item))
  end

  def multiple_artists
    item = Item.new(
      id: 3,
      title: 'V-ROCK FESTIVAL 2026 COMPILATION ALBUM',
      release_date: Date.new(2026, 5, 15),
      image_url: 'https://m.media-amazon.com/images/I/51EXAMPLE._SL160_.jpg',
      link_url: 'https://www.amazon.co.jp/exec/obidos/ASIN/B0EXAMPLE3/vkdb07-22/',
      artists: [
        { 'name' => 'lynch.', 'old_key' => '%A5%EA%A5%F3%A5%C1' },
        { 'name' => 'DIR EN GREY', 'old_key' => '%A5%C7%A5%A3%A5%EB%A5%A2%A5%F3%A5%B0%A5%EC%A5%A4' },
        { 'name' => 'MUCC', 'old_key' => '%A5%E0%A5%C3%A5%AF' }
      ]
    )

    render(ItemCardComponent.new(item_card: item))
  end

  def artist_without_old_key
    item = Item.new(
      id: 4,
      title: 'NEW ARTIST DEBUT ALBUM',
      release_date: Date.new(2026, 6, 1),
      image_url: 'https://m.media-amazon.com/images/I/51NEWARTIST._SL160_.jpg',
      link_url: 'https://www.amazon.co.jp/exec/obidos/ASIN/B0EXAMPLE4/vkdb07-22/',
      artists: [
        { 'name' => 'New Artist' }
      ]
    )

    render(ItemCardComponent.new(item_card: item))
  end

  def with_key_artist
    item = Item.new(
      id: 5,
      title: 'SomeArtist 1st ALBUM',
      release_date: Date.new(2026, 4, 1),
      image_url: 'https://m.media-amazon.com/images/I/51EXAMPLE._SL160_.jpg',
      link_url: 'https://www.amazon.co.jp/exec/obidos/ASIN/B0EXAMPLE5/vkdb07-22/',
      artists: [
        { 'name' => 'SomeArtist', 'key' => 'some-artist', 'old_key' => '%A5%BD%A5%E1' }
      ]
    )

    render(ItemCardComponent.new(item_card: item))
  end
end

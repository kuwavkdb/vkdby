# frozen_string_literal: true

# パート（個人・メンバー）ごとのアイコンSVGを出すヘルパー（issue #2144）。
# 管理画面のパート選択（ラジオボタン・チェックボックス）で、パート名の横に飾りとして出す。
#
# 図形は Lucide（https://lucide.dev, lucide-static v0.460.0）のアイコンから取っている。
# ぴったりのアイコンが無いパートは近いもので代用している（ベース: ギターを左右反転、ヴァイオリン: 音符）。
#
# --- Lucide のライセンス ---
# ISC License
#
# Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022 as part of Feather (MIT).
# All other copyright (c) for Lucide are held by Lucide Contributors 2022.
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
module PartIconHelper # rubocop:disable Metrics/ModuleLength -- 大半はアイコンの図形データ
  GUITAR_SHAPES = <<~SVG.squish
    <path d="m11.9 12.1 4.514-4.514"/>
    <path d="M20.1 2.3a1 1 0 0 0-1.4 0l-1.114 1.114A2 2 0 0 0 17 4.828v1.344a2 2 0 0 1-.586 1.414A2 2 0 0 1 17.828 7h1.344a2 2 0 0 0 1.414-.586L21.7 5.3a1 1 0 0 0 0-1.4z"/>
    <path d="m6 16 2 2"/>
    <path d="M8.2 9.9C8.7 8.8 9.8 8 11 8c2.8 0 5 2.2 5 5 0 1.2-.8 2.3-1.9 2.8l-.9.4A2 2 0 0 0 12 18a4 4 0 0 1-4 4c-3.3 0-6-2.7-6-6a4 4 0 0 1 4-4 2 2 0 0 0 1.8-1.2z"/>
    <circle cx="11.5" cy="12.5" r=".5" fill="currentColor"/>
  SVG

  # パート（enum のキー）ごとの、<svg> の中に入れる図形。
  PART_ICON_SHAPES = {
    # Lucide: mic-vocal
    'vocal' => <<~SVG.squish,
      <path d="m11 7.601-5.994 8.19a1 1 0 0 0 .1 1.298l.817.818a1 1 0 0 0 1.314.087L15.09 12"/>
      <path d="M16.5 21.174C15.5 20.5 14.372 20 13 20c-2.058 0-3.928 2.356-6 2-2.072-.356-2.775-3.369-1.5-4.5"/>
      <circle cx="16" cy="7" r="5"/>
    SVG
    # Lucide: guitar
    'guitar' => GUITAR_SHAPES,
    # Lucide: guitar を左右反転（ギターと見分けるため）
    'bass' => %(<g transform="matrix(-1 0 0 1 24 0)">#{GUITAR_SHAPES}</g>),
    # Lucide: drum
    'drums' => <<~SVG.squish,
      <path d="m2 2 8 8"/>
      <path d="m22 2-8 8"/>
      <ellipse cx="12" cy="9" rx="10" ry="5"/>
      <path d="M7 13.4v7.9"/>
      <path d="M12 14v8"/>
      <path d="M17 13.4v7.9"/>
      <path d="M2 9v8a10 5 0 0 0 20 0V9"/>
    SVG
    # Lucide: keyboard-music
    'keyboard' => <<~SVG.squish,
      <rect width="20" height="16" x="2" y="4" rx="2"/>
      <path d="M6 8h4"/>
      <path d="M14 8h.01"/>
      <path d="M18 8h.01"/>
      <path d="M2 12h20"/>
      <path d="M6 12v4"/>
      <path d="M10 12v4"/>
      <path d="M14 12v4"/>
      <path d="M18 12v4"/>
    SVG
    # Lucide: piano
    'piano' => <<~SVG.squish,
      <path d="M18.5 8c-1.4 0-2.6-.8-3.2-2A6.87 6.87 0 0 0 2 9v11a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-8.5C22 9.6 20.4 8 18.5 8"/>
      <path d="M2 14h20"/>
      <path d="M6 14v4"/>
      <path d="M10 14v4"/>
      <path d="M14 14v4"/>
      <path d="M18 14v4"/>
    SVG
    # Lucide: music（ヴァイオリンのアイコンが無いため音符で代用）
    'violin' => <<~SVG.squish,
      <path d="M9 18V5l12-2v13"/>
      <circle cx="6" cy="18" r="3"/>
      <circle cx="18" cy="16" r="3"/>
    SVG
    # Lucide: disc-3
    'dj' => <<~SVG.squish,
      <circle cx="12" cy="12" r="10"/>
      <path d="M6 12c0-1.7.7-3.2 1.8-4.2"/>
      <circle cx="12" cy="12" r="2"/>
      <path d="M18 12c0 1.7-.7 3.2-1.8 4.2"/>
    SVG
    # Lucide: person-standing
    'dancer' => <<~SVG.squish,
      <circle cx="12" cy="5" r="1"/>
      <path d="m9 20 3-6 3 6"/>
      <path d="m6 8 6 2 6-2"/>
      <path d="M12 10v4"/>
    SVG
    # Lucide: drama
    'performer' => <<~SVG.squish,
      <path d="M10 11h.01"/>
      <path d="M14 6h.01"/>
      <path d="M18 6h.01"/>
      <path d="M6.5 13.1h.01"/>
      <path d="M22 5c0 9-4 12-6 12s-6-3-6-12c0-2 2-3 6-3s6 1 6 3"/>
      <path d="M17.4 9.9c-.8.8-2 .8-2.8 0"/>
      <path d="M10.1 7.1C9 7.2 7.7 7.7 6 8.6c-3.5 2-4.7 3.9-3.7 5.6 4.5 7.8 9.5 8.4 11.2 7.4.9-.5 1.9-2.1 1.9-4.7"/>
      <path d="M9.1 16.5c.3-1.1 1.4-1.7 2.4-1.4"/>
    SVG
    # Lucide: sliders-vertical
    'manipulator' => <<~SVG.squish,
      <line x1="4" x2="4" y1="21" y2="14"/>
      <line x1="4" x2="4" y1="10" y2="3"/>
      <line x1="12" x2="12" y1="21" y2="12"/>
      <line x1="12" x2="12" y1="8" y2="3"/>
      <line x1="20" x2="20" y1="21" y2="16"/>
      <line x1="20" x2="20" y1="12" y2="3"/>
      <line x1="2" x2="6" y1="14" y2="14"/>
      <line x1="10" x2="14" y1="8" y2="8"/>
      <line x1="18" x2="22" y1="16" y2="16"/>
    SVG
    # Lucide: ellipsis
    'etc' => <<~SVG.squish,
      <circle cx="12" cy="12" r="1"/>
      <circle cx="19" cy="12" r="1"/>
      <circle cx="5" cy="12" r="1"/>
    SVG
    # Lucide: id-card
    'staff' => <<~SVG.squish,
      <path d="M16 10h2"/>
      <path d="M16 14h2"/>
      <path d="M6.17 15a3 3 0 0 1 5.66 0"/>
      <circle cx="9" cy="11" r="2"/>
      <rect x="2" y="5" width="20" height="14" rx="2"/>
    SVG
    # Lucide: circle-help
    'unknown' => <<~SVG.squish
      <circle cx="12" cy="12" r="10"/>
      <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/>
      <path d="M12 17h.01"/>
    SVG
  }.freeze

  # part: パートのキー（'vocal' など。シンボルも可）。
  # アイコンの無いパートは nil を返す（呼び出し側は文字だけを出す）。
  # アイコンは飾りなので aria-hidden にする。パート名は呼び出し側で文字として出すこと。
  def part_icon(part, css_class: 'w-5 h-5')
    shapes = PART_ICON_SHAPES[part.to_s]
    return if shapes.nil?

    svg = <<~SVG.squish
      <svg class="#{ERB::Util.html_escape(css_class)}" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
           fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
           aria-hidden="true" focusable="false">#{shapes}</svg>
    SVG
    svg.html_safe
  end
end

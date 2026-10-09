# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin 'application', preload: true
pin 'sortablejs' # @1.15.6
pin '@hotwired/stimulus', to: 'stimulus.min.js'
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js'
pin_all_from 'app/javascript/controllers', under: 'controllers', to: 'controllers'
# 会場の地図（issue #1801）。地図を表示するページで venue_map_controller から動的に読み込むため preload しない
pin_all_from 'app/javascript/venue_map', under: 'venue_map', to: 'venue_map', preload: false
pin 'marked' # @17.0.3
pin 'htmx.org', to: 'https://unpkg.com/htmx.org@2.0.11/dist/htmx.esm.js'
pin 'js-yaml' # @5.4.2

// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "controllers"
import htmx from 'htmx.org'
window.htmx = htmx
document.addEventListener('turbo:load', () => htmx.process(document.body))

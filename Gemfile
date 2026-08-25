# frozen_string_literal: true

source 'https://rubygems.org'

ruby '4.0.2'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '>= 8.1.2.1', '~> 8.1.2'
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'propshaft'
# Use pg as the database for Active Record
gem 'pg', '~> 1.5'
# mysql2 is in :development group (legacy data migration only)
# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 5.0'
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem 'bcrypt', '~> 3.1.22'
# gem "omniauth"
# gem "omniauth-google-oauth2"
# gem "omniauth-rails_csrf_protection"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# solid_cable, solid_cache, solid_queue are in :development group (production uses Redis)

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem 'kamal', require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem 'tailwindcss-rails'
gem 'thruster', require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem 'aws-sdk-s3', require: false
gem 'image_processing', '~> 2.0'
gem 'mini_magick'
# 画像添付ファイルのメタデータ解析（width/height抽出）用。Dockerfileでlibvips(C library)を
# インストール済みだが、ruby側のバインディングgemが無いためActiveStorageの画像解析
# （ActiveStorage::Analyzer::ImageAnalyzer::Vips）が動作せずwidth/heightが取得できていなかった
# （issue #1215）。mini_magickが要求するImageMagick CLIは未インストールのためvipsを採用する。
# require: false必須: ActiveStorage側(active_storage/analyzer/image_analyzer/vips.rb)が
# 自前でrequire "ruby-vips"をLoadErrorごとrescueして安全に読み込むため、Bundler.require由来の
# 即時requireを無効化しない場合、libvips(共有ライブラリ)が入っていない環境（CIのtest/system-test/
# scan_js等）でアプリ起動自体がBundler::GemRequireErrorで落ちてしまう。
gem 'ruby-vips', require: false
gem 'view_component'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[mri mingw mswin x64_mingw], require: 'debug/prelude'

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem 'bundler-audit', require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem 'rubocop-rails-omakase', require: false
end

group :development do
  gem 'ruby-lsp'
  gem 'solargraph', '~> 0.60'

  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'annotaterb'
  gem 'web-console'

  gem 'lookbook'

  # Legacy data migration from vkdb MySQL database
  gem 'mysql2', '~> 0.5'

  # Rails 8 defaults — not used in production (Redis is used instead)
  gem 'solid_cable'
  gem 'solid_cache'
  gem 'solid_queue'
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'selenium-webdriver'
end

gem 'redis', '>= 4.0.1'

gem 'discard', '~> 2.0'
gem 'rack-attack'
gem 'romaji', '~> 0.3.0'

gem 'pagy', '~> 43.6'
gem 'redcarpet'

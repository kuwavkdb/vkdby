# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Vkdby
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Use mini_magick for Active Storage variants; the app bundles mini_magick,
    # not the vips gem that Rails 8.1's load_defaults selects by default.
    config.active_storage.variant_processor = :mini_magick

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Add app/assets/builds to the asset load path
    config.assets.paths << Rails.root.join('app/assets/builds')

    # Insert middleware to fix EUC-JP URLs before ActionableExceptions
    # (or any other middleware that might raise BadRequest on invalid encoding)
    require_relative '../lib/middleware/euc_jp_url_fixer'
    config.middleware.insert_before 0, Middleware::EucJpUrlFixer

    # Insert IP blocker middleware (runs after EucJpUrlFixer)
    require_relative '../lib/middleware/ip_blocker'
    config.middleware.insert_after Middleware::EucJpUrlFixer, Middleware::IpBlocker

    # Set default locale to Japanese
    config.i18n.default_locale = :ja

    # Site name used in page titles
    config.site_name = ENV.fetch('SITE_NAME', 'vkdb.jp')

    # Base URL for old-key links to the legacy site (issue #946).
    # Only relevant during the migration period; remove once the old site is retired.
    config.old_key_url_base = ENV.fetch('OLD_KEY_URL_BASE', 'https://wiki.vkdb.jp')

    # Google Custom Search Engine ID, offered as a supplementary web-wide search
    # option alongside the internal DB search on error pages (issue #962).
    config.google_cse_id = ENV.fetch('GOOGLE_CSE_ID', '012501366286233936630:nhzl-0aow2y')

    # TagIndex IDs that mark a Person/Unit as unpublished (content hidden, see issue #919).
    # Override per environment in config/environments/*.rb if needed.
    config.unpublished_tag_ids = [2643]

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end

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
    #
    # We do NOT switch this to :vips just to enable image analysis (width/height
    # extraction, issue #1215): ActiveStorage::Blob variant-transformer setup in
    # Rails 8.1's engine.rb only rescues LoadError messages matching /libvips/ or
    # /image_processing/, but image_processing's own error text is
    # "ImageProcessing::Vips requires..." (capitalized, no underscore) — it doesn't
    # match, so the rescue falls through to `raise` and boot crashes on any machine
    # without libvips installed (dev machines, CI). See
    # lib/active_storage_ext/safe_vips_image_analyzer.rb for how we use vips for
    # analysis only, decoupled from variant_processor.
    config.active_storage.variant_processor = :mini_magick

    # Serve Active Storage files via the proxy route (streamed through the app)
    # instead of the default redirecting route (issue #1241). url_for(blob/attachment)
    # — used by Admin::ImagesController#show to produce the URL that gets pasted into
    # markdown content (Units/People/CustomPages) — now generates
    # /rails/active_storage/blobs/proxy/... URLs, avoiding an extra 302 hop to the
    # storage service (Cloudflare R2) on every image request. Only affects URLs
    # generated from now on; URLs already embedded in existing content are unaffected.
    config.active_storage.resolve_model_to_route = :rails_storage_proxy

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # active_storage_ext: extension classes reopening ActiveStorage internals
    # (see below) whose constant names don't follow the file path convention
    # Zeitwerk expects, so they're required manually instead of autoloaded.
    config.autoload_lib(ignore: %w[assets tasks active_storage_ext])

    # Register a vips-based ActiveStorage image analyzer that works regardless of
    # variant_processor, so markdown-embedded images get width/height metadata
    # (CLS fix, issue #1215) without requiring variant_processor: :vips (see above).
    # Safe when libvips itself isn't installed: the analyzer's own require is
    # guarded and it silently yields no metadata rather than failing analysis.
    require_relative '../lib/active_storage_ext/safe_vips_image_analyzer'
    config.active_storage.analyzers.unshift(ActiveStorage::Analyzer::ImageAnalyzer::SafeVips)

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

    # Default meta description for pages that don't set content_for(:description) (issue #1223)
    config.site_description = ENV.fetch(
      'SITE_DESCRIPTION',
      'ヴィジュアル系バンド・アーティストのデータベース。ユニットやメンバーの結成・脱退・改名などの活動履歴、プロフィール、動向、年表を掲載しています。'
    )

    # Default OGP/Twitter Card image for pages that don't set a page-specific image
    # (issue #1253). Unit/Person page images taking priority over this default is a
    # follow-up, same phased approach as meta description (issue #1223).
    config.site_ogp_image_path = ENV.fetch('SITE_OGP_IMAGE_PATH', '/icon.png')

    # Base URL for old-key links to the legacy site (issue #946).
    # Only relevant during the migration period; remove once the old site is retired.
    config.old_key_url_base = ENV.fetch('OLD_KEY_URL_BASE', 'https://wiki.vkdb.jp')

    # Canonical host for <link rel="canonical"> on unit/person pages (issue #1208).
    # Currently running on a pre-production subdomain that differs from the production
    # domain (www.vkdb.jp); set to prevent the subdomain from being indexed as the
    # canonical source. TODO: once the production domain switch is complete, remove
    # this setting and the canonical tag output that references it.
    config.canonical_host = ENV.fetch('CANONICAL_HOST', nil)

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

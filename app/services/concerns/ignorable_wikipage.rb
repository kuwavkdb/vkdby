# frozen_string_literal: true

module IgnorableWikipage
  extend ActiveSupport::Concern

  IGNORED_TITLE_PATTERNS = [
    %r{^カレンダー/},
    %r{^オフィシャルサイト/},
    %r{^インディーズ/},
    /_comment$/
  ].freeze

  class_methods do
    def ignored?(wikipage)
      title = wikipage.title.to_s
      name = wikipage.name.to_s
      IGNORED_TITLE_PATTERNS.any? { |pattern| pattern.match?(title) || pattern.match?(name) }
    end
  end
end

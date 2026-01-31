# frozen_string_literal: true

module IgnorableWikipage
  extend ActiveSupport::Concern

  IGNORED_TITLE_PATTERNS = [
    %r{^カレンダー/},
    %r{^オフィシャルサイト/},
    %r{^インディーズ/},
    %r{^発売スケジュール/},
    %r{^出身地/},
    %r{^動向/},
    %r{^血液型/},
    %r{^同名/},
    /^BBS-/,
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

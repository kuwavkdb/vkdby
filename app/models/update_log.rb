# frozen_string_literal: true

class UpdateLog < ApplicationRecord
  belongs_to :user
  belongs_to :loggable, polymorphic: true, optional: true

  validates :action, inclusion: { in: %w[create update discard undiscard] }
end

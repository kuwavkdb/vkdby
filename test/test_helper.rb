# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Temporarily replaces a class method with a fixed value (or a callable that receives
    # the original arguments) for the duration of the block, then restores it.
    # Minitest 6 removed Object#stub (mocking moved out of the gem) and this project has
    # no mocking gem, so this is a minimal stand-in for the handful of tests that need to
    # fake a class method (e.g. OgpImageGenerator.call so model tests don't depend on
    # libvips being installed, issue #1259).
    def stub_class_method(klass, method_name, value)
      original = klass.method(method_name)
      klass.define_singleton_method(method_name) do |*args|
        value.respond_to?(:call) ? value.call(*args) : value
      end
      yield
    ensure
      klass.define_singleton_method(method_name, original)
    end
  end
end

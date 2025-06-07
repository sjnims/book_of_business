ENV["RAILS_ENV"] ||= "test"

# Code coverage setup - must be before loading Rails
require "simplecov"
require "simplecov-cobertura"

SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/vendor/"

  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CoberturaFormatter,
  ])
end

require_relative "../config/environment"
require "rails/test_help"
require "minitest/reporters"

# Configure reporters based on environment
if ENV["CI"]
  # In CI, use both JUnit (for test results) and Progress (for console output)
  Minitest::Reporters.use!(
    [
      Minitest::Reporters::JUnitReporter.new("tmp/test-results"),
      Minitest::Reporters::ProgressReporter.new,
    ],
    ENV,
    Minitest.backtrace_filter
  )
else
  # In development, just use the progress reporter
  Minitest::Reporters.use!(
    Minitest::Reporters::ProgressReporter.new,
    ENV,
    Minitest.backtrace_filter
  )
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

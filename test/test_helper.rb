ENV["RAILS_ENV"] ||= "test"

# Code coverage setup - must be before loading Rails
require "simplecov"
require "simplecov-cobertura"

SimpleCov.start "rails" do
  root File.expand_path("..", __dir__)
  
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/vendor/"
  add_filter "/db/"
  add_filter "/bin/"
  
  # Ensure proper source file detection
  track_files "{app,lib}/**/*.rb"

  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CoberturaFormatter,
  ])
  
  # Add metadata for Codecov
  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Services", "app/services"
  add_group "Helpers", "app/helpers"
  add_group "Libraries", "lib"
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

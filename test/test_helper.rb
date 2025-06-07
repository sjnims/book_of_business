ENV["RAILS_ENV"] ||= "test"

# Code coverage setup - must be before loading Rails
require "simplecov"
require "simplecov-cobertura"
require_relative "../lib/simplecov_console_formatter"

# Configure SimpleCov for parallel testing
SimpleCov.use_merging true
SimpleCov.command_name "rails_test_#{$$}" # Use process ID for uniqueness

SimpleCov.start "rails" do
  root File.expand_path("..", __dir__)

  add_filter "/test/"
  add_filter "/config/"
  add_filter "/vendor/"
  add_filter "/db/"
  add_filter "/bin/"
  add_filter "/tmp/"
  add_filter "/coverage/"
  add_filter "/lib/simplecov_console_formatter.rb"

  # Ensure proper source file detection
  track_files "{app,lib}/**/*.rb"

  # Enable branch coverage
  enable_coverage :branch

  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::CoberturaFormatter,
    SimplecovConsoleFormatter,
  ])

  # Add metadata for Codecov
  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Services", "app/services"
  add_group "Helpers", "app/helpers"
  add_group "Libraries", "lib"
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"

  # Set minimum coverage
  minimum_coverage 80 if ENV["CI"]
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

    # Configure parallel test hooks for SimpleCov
    parallelize_setup do |worker|
      # Each worker gets a unique command name
      SimpleCov.command_name "rails_test_worker_#{worker}"
    end

    parallelize_teardown do |worker|
      # Ensure results are written
      SimpleCov.result
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Helper method to clean database for tests that need isolation from fixtures
    def clean_database!
      # Disable audit logging during cleanup
      Current.user = nil

      # Clean in correct order to avoid foreign key constraints
      AuditLog.delete_all
      Service.delete_all
      Order.delete_all
      Customer.delete_all
      User.delete_all
    end
  end
end

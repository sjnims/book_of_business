namespace :coverage do
  desc "Collate simplecov results from parallel test runs"
  task :report do
    require "simplecov"
    require "simplecov-cobertura"
    require_relative "../simplecov_console_formatter"

    SimpleCov.collate Dir["coverage/.resultset*.json"], "rails" do
      formatter SimpleCov::Formatter::MultiFormatter.new([
        SimpleCov::Formatter::HTMLFormatter,
        SimpleCov::Formatter::CoberturaFormatter,
        SimpleCovConsoleFormatter,
      ])

      add_group "Models", "app/models"
      add_group "Controllers", "app/controllers"
      add_group "Services", "app/services"
      add_group "Helpers", "app/helpers"
      add_group "Libraries", "lib"
      add_group "Jobs", "app/jobs"
      add_group "Mailers", "app/mailers"
    end
  end
end

# Hook into the default test task to generate coverage report
Rake::Task["test"].enhance do
  Rake::Task["coverage:report"].invoke
end

namespace :hooks do
  desc "Install git hooks for code quality checks"
  task :install do
    puts "Installing git hooks..."
    system("git config core.hooksPath .githooks")

    if $?.success?
      puts "✅ Git hooks installed successfully!"
      puts "\nPre-commit hook will check:"
      puts "  • Ruby syntax"
      puts "  • RuboCop style violations"
      puts "  • Test failures"
      puts "  • Documentation (warnings only)"
      puts "\nTo bypass hooks in an emergency: git commit --no-verify"
    else
      puts "❌ Failed to install git hooks"
      exit 1
    end
  end

  desc "Uninstall git hooks"
  task :uninstall do
    puts "Uninstalling git hooks..."
    system("git config --unset core.hooksPath")
    puts "✅ Git hooks uninstalled"
  end

  desc "Run pre-commit checks manually"
  task :check do
    puts "Running pre-commit checks manually..."
    system("ruby .githooks/pre-commit")
  end
end

# Note: To automatically install hooks after bundle install,
# you can add this to your Gemfile:
#
# at_exit do
#   if $?.success? && File.exist?('.githooks/pre-commit')
#     system("rails hooks:install")
#   end
# end

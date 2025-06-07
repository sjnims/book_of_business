require "simplecov"

# Custom SimpleCov formatter that displays coverage results in the console
# Groups files by category and shows coverage percentages with color coding
class SimplecovConsoleFormatter
  # Formats SimpleCov results for console output
  #
  # @param result [SimpleCov::Result] The coverage result from SimpleCov
  # @return [String] Formatted coverage report for console display
  def format(result)
    puts "\n" + "="*80
    puts "Coverage Report by File"
    puts "="*80

    # Group files by their group name
    groups = {}
    result.files.each do |file|
      group_name = nil
      result.groups.each do |name, group|
        if group.include?(file)
          group_name = name
          break
        end
      end
      group_name ||= "Other"
      groups[group_name] ||= []
      groups[group_name] << file
    end

    # Sort groups and display files within each group
    groups.keys.sort.each do |group_name|
      puts "\n#{group_name}:"
      puts "-" * group_name.length

      files = groups[group_name].sort_by(&:filename)
      files.each do |file|
        # Get relative path from Rails root
        relative_path = file.filename.sub("#{Rails.root}/", "")
        coverage_percent = file.covered_percent.round(1)

        # Color code based on coverage percentage
        color = case coverage_percent
        when 90..100 then "\e[32m" # Green
        when 75..89  then "\e[33m" # Yellow
        else "\e[31m"              # Red
        end

        # Reset color
        reset = "\e[0m"

        printf "  %-60s %s%6.1f%%%s\n", relative_path, color, coverage_percent, reset
      end
    end

    puts "\n" + "="*80
    puts "Overall Coverage: #{result.covered_percent.round(2)}%"
    puts "="*80

    # Return empty string as we're just printing to console
    ""
  end
end

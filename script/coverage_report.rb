#!/usr/bin/env ruby

require 'json'

# Read the coverage result file
coverage_file = File.join(Dir.pwd, 'coverage', '.resultset.json')

unless File.exist?(coverage_file)
  puts "Coverage file not found. Please run tests first."
  exit 1
end

data = JSON.parse(File.read(coverage_file))

# Merge coverage data from all test runs
merged_coverage = {}

data.each do |run_name, run_data|
  next unless run_data['coverage']

  run_data['coverage'].each do |file, file_coverage|
    if merged_coverage[file].nil?
      merged_coverage[file] = file_coverage
    elsif file_coverage.is_a?(Hash) && file_coverage['lines']
      # Merge line coverage
      if merged_coverage[file].is_a?(Hash) && merged_coverage[file]['lines']
        file_coverage['lines'].each_with_index do |count, index|
          if count && merged_coverage[file]['lines'][index]
            merged_coverage[file]['lines'][index] += count
          elsif count
            merged_coverage[file]['lines'][index] = count
          end
        end
      end
    end
  end
end

coverage_data = merged_coverage

# Calculate per-file coverage
puts "Per-file coverage report:"
puts "=" * 60

total_lines = 0
total_covered = 0

coverage_data.each do |file, coverage|
  next unless file.start_with?(Dir.pwd)
  next unless coverage.is_a?(Hash) && coverage['lines']

  lines = coverage['lines']
  covered = lines.compact.count { |n| n && n.positive? }
  total = lines.compact.count

  next if total.zero?

  total_lines += total
  total_covered += covered

  percentage = (covered.to_f / total * 100).round(2)
  relative_path = file.sub(Dir.pwd + '/', '')

  puts "#{relative_path}: #{percentage}% (#{covered}/#{total} lines)"
end

puts "=" * 60
puts "Total: #{(total_covered.to_f / total_lines * 100).round(2)}% (#{total_covered}/#{total_lines} lines)"

# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

desc "Run tests for domain layer only"
Rake::TestTask.new(:test_domain) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/domain_test.rb"]
  t.warning = false
end

desc "Run tests for scenarios"
Rake::TestTask.new(:test_scenarios) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/option*_test.rb"]
  t.warning = false
end

task default: :test

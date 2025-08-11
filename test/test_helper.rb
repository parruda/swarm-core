# frozen_string_literal: true

require "simplecov"
SimpleCov.external_at_exit = true
SimpleCov.start do
  add_filter "/test/"
  add_filter "/vendor/"
  add_filter "/version.rb"
  add_group "Library", "lib"
  track_files "{lib}/**/*.rb"
end

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "swarm_core"
require "minitest/autorun"
require "mocha/minitest"

# Set up a temporary home directory for all tests
require "tmpdir"
TEST_SWARM_HOME = Dir.mktmpdir("swarm-core-test")

# Clean up the test home directory after all tests
Minitest.after_run do
  FileUtils.rm_rf(TEST_SWARM_HOME)
end

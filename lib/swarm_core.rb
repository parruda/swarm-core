# frozen_string_literal: true

require_relative "swarm_core/version"

# Zeitwerk setup
require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "cli" => "CLI",
  "openai" => "OpenAI",
)
loader.setup

module SwarmCore
  class Error < StandardError; end
  # Your code goes here...
end

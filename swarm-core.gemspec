# frozen_string_literal: true

require_relative "lib/swarm_core/version"

Gem::Specification.new do |spec|
  spec.name = "swarm-core"
  spec.version = SwarmCore::VERSION
  spec.authors = ["Paulo Arruda"]
  spec.email = ["parrudaj@gmail.com"]

  spec.summary = "A framework for developing agentic systems in Ruby"
  spec.description = <<~DESC
    Swarm Core is a Ruby framework for developing agentic systems, inspired by Claude Swarm.
    It enables orchestration of multiple AI agents with specialized roles, tools, and
    directory contexts, communicating through tool calls in a tree-like hierarchy.
  DESC
  spec.homepage = "https://github.com/parruda/swarm-core"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/parruda/swarm-core"
  spec.metadata["changelog_uri"] = "https://github.com/parruda/swarm-core/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(["git", "ls-files", "-z"], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?("bin/", "test/", "spec/", "features/", ".git", ".github", "appveyor", "Gemfile")
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html

  spec.add_dependency("dry-cli", "~> 1.3")
  spec.add_dependency("ruby-mcp-client", "~> 0.7")
  spec.add_dependency("zeitwerk", "~> 2.6")
end

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Testing
- Run all tests: `bundle exec rake test`
- Run a specific test file: `bundle exec ruby test/path/to/test_file.rb`
- Run tests with coverage: Add `COVERAGE=true` before the test command

### Linting and Code Quality
- Always run RuboCop linter with Auto-fixing: `bundle exec rubocop -A`
- The project uses rubocop-shopify configuration with additional plugins for minitest and rake

### Development
- Install dependencies: `bundle install`
- Build gem: `bundle exec rake build`

### Default Task
- Run tests and linter together: `bundle exec rake` or just `rake`

## Architecture

### Core Structure
SwarmCore is a Ruby framework for developing agentic systems, inspired by Claude Swarm. It orchestrates multiple AI agents with specialized roles, tools, and directory contexts, communicating through tool calls in a tree-like hierarchy.

### Key Components

#### Core Classes

##### AgentDefinition (`lib/swarm_core/agent_definition.rb`)
- Represents the static configuration of an agent from YAML
- Validates required fields (description, provider, model)
- Manages tool permissions with allowed/disallowed lists
- Handles MCP server configurations and hooks
- Validates provider compatibility
- Provides `valid?` and `errors` methods for validation

##### Agent (`lib/swarm_core/agent.rb`)
- Represents a runtime instance of an agent with unique ID
- Manages parent-child relationships in the agent hierarchy
- Tracks conversation history with timestamps
- Spawns child agents (reports) maintaining session context
- Provides tree navigation (ancestors, descendants, depth)
- Uses dependency injection for ID generation and time providers

##### Swarm (`lib/swarm_core/swarm.rb`)
- Orchestrates the entire swarm of agents
- Parses and validates YAML configuration
- Detects circular dependencies in agent reports
- Manages swarm lifecycle (start, spawn agents)
- Executes before_start commands
- Maintains active agent registry
- Uses dependency injection for system commands, YAML parsing, and agent factory

##### SystemUtils (`lib/swarm_core/system_utils.rb`)
- Provides robust system command execution using Open3
- Captures STDOUT and STDERR separately
- Supports real-time output streaming
- Implements command timeout functionality
- Checks command existence in PATH
- Returns CommandResult struct with comprehensive execution details
- Handles errors gracefully with proper exit codes

#### Current Team Members for SwarmCore development
- **lead_developer**: Main coordinator for swarm-core development
- **github_expert**: Handles all Git and GitHub operations via gh CLI
- **fast_mcp_expert**: MCP server development and FastMCP architecture
- **ruby_mcp_client_expert**: MCP client integration and multi-transport connectivity
- **ruby_llm_expert**: RubyLLM gem integration for unified AI model interactions
- **dry_cli_expert**: CLI architecture using dry-cli gem

### Dependencies
- **dry-cli (~> 1.3)**: For building modular CLI interfaces
- **ruby-mcp-client (~> 0.7)**: MCP client connectivity
- **zeitwerk (~> 2.6)**: Code loading and autoloading

### Code Loading
The project uses Zeitwerk for automatic code loading with custom inflections:
- "cli" → "CLI"
- "openai" → "OpenAI"

### Testing Framework
- Uses Minitest as the testing framework
- Test files are in the `test/` directory
- Includes Mocha for mocking, but only use it when strictly necessary
- SimpleCov for code coverage
- WebMock / VCR for HTTP request stubbing
- Use Factory Bot and Faker instead of fixtures

### Testing Guidelines
- Use Minitest block syntax: `test "description" do ... end` instead of `def test_method_name`
- Achieve at least 90% branch coverage - test all code paths and edge cases
- Write tests for behaviour rather then being coupled with the implementation
- Only use mocks/stubs when strictly necessary - Over mocking/stubbing is bad
- Ensure the tests actually provide value - do NOT mock everything and test the mocks
- Avoid excessive mocking just to achieve coverage - tests should verify real behavior
- Use VCR / Webmock for tests that involve API requests
- Always use Factories, NOT Fixtures.

### Important Conventions
- Ruby version requirement: >= 3.2.0
- Follows Shopify's Ruby style guide via rubocop-shopify
- Gem is configured to push to https://rubygems.org
- Uses semantic versioning (version defined in `lib/swarm_core/version.rb`)
- Git-based file inclusion for gem packaging (excludes test, spec, and development files)

### MCP Integration Focus
The gem is designed to work with the Model Context Protocol (MCP), enabling:
- Tool definition and validation
- Resource management for data sharing
- Multiple transport protocols (STDIO, HTTP, SSE)
- Session management and persistence
- Inter-instance communication mechanisms

When developing features, always consider:
- **Design for testability** - All code must be designed with testing in mind. It should be easy to test
- Use dependency injection, avoid hard-coded dependencies, and keep methods small and focused
- Comprehensive test coverage
- Following existing code patterns and conventions
- Running both tests (`bundle exec rake test`) and linter (`bundle exec rubocop -A`)
- Keep the README.md always updated
- **Update CLAUDE.md** - When adding new classes or significantly changing existing ones, update the "Core Classes" section with their responsibilities and key features
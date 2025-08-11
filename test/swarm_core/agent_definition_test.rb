# frozen_string_literal: true

require "test_helper"

module SwarmCore
  class AgentDefinitionTest < Minitest::Test
    def test_valid_agent_definition
      config = {
        "description" => "Test agent",
        "provider" => "anthropic",
        "model" => "claude-3",
        "path" => "./test",
        "system_prompt" => "You are a test agent",
      }

      definition = AgentDefinition.new("test_agent", config)

      assert_predicate(definition, :valid?)
      assert_empty(definition.errors)
      assert_equal("test_agent", definition.name)
      assert_equal("Test agent", definition.description)
      assert_equal("anthropic", definition.provider)
      assert_equal("claude-3", definition.model)
    end

    def test_missing_required_fields
      config = {
        "path" => "./test",
      }

      definition = AgentDefinition.new("test_agent", config)

      refute_predicate(definition, :valid?)
      assert_includes(definition.errors, "Agent 'test_agent': description is required")
      assert_includes(definition.errors, "Agent 'test_agent': provider is required")
      assert_includes(definition.errors, "Agent 'test_agent': model is required")
    end

    def test_invalid_provider
      config = {
        "description" => "Test agent",
        "provider" => "invalid_provider",
        "model" => "some-model",
      }

      definition = AgentDefinition.new("test_agent", config)

      refute_predicate(definition, :valid?)
      assert_includes(definition.errors, "Agent 'test_agent': Invalid provider 'invalid_provider'. Must be one of: anthropic, openai, google")
    end

    def test_tool_configuration_parsing
      config = {
        "description" => "Test agent",
        "provider" => "anthropic",
        "model" => "claude-3",
        "allowed_tools" => [
          "Bash",
          { "tool" => "Edit", "matcher" => "/.*\\.rb$/" },
          "Write",
        ],
        "disallowed_tools" => ["Task"],
      }

      definition = AgentDefinition.new("test_agent", config)

      assert_predicate(definition, :valid?)
      assert_equal(3, definition.allowed_tools.length)
      assert_equal("Bash", definition.allowed_tools[0][:name])
      assert_nil(definition.allowed_tools[0][:matcher])
      assert_equal("Edit", definition.allowed_tools[1][:name])
      assert_equal("/.*\\.rb$/", definition.allowed_tools[1][:matcher])
    end

    def test_can_use_tool_with_default_tools
      config = {
        "description" => "Test agent",
        "provider" => "anthropic",
        "model" => "claude-3",
      }

      definition = AgentDefinition.new("test_agent", config)

      # Default tools should be allowed
      assert(definition.can_use_tool?("Read"))
      assert(definition.can_use_tool?("Glob"))
      assert(definition.can_use_tool?("LS"))
      assert(definition.can_use_tool?("Grep"))
      assert(definition.can_use_tool?("TodoWrite"))
      assert(definition.can_use_tool?("Task"))

      # Non-default tools should not be allowed by default
      refute(definition.can_use_tool?("Bash"))
      refute(definition.can_use_tool?("Write"))
    end

    def test_can_use_tool_with_allowed_and_disallowed
      config = {
        "description" => "Test agent",
        "provider" => "anthropic",
        "model" => "claude-3",
        "allowed_tools" => ["Bash", "Write"],
        "disallowed_tools" => ["Task", "Bash"],
      }

      definition = AgentDefinition.new("test_agent", config)

      # Disallowed takes precedence
      refute(definition.can_use_tool?("Bash"))
      refute(definition.can_use_tool?("Task"))

      # Allowed tools work
      assert(definition.can_use_tool?("Write"))

      # Default tools still work unless disallowed
      assert(definition.can_use_tool?("Read"))
    end

    def test_mcp_server_validation
      config = {
        "description" => "Test agent",
        "provider" => "anthropic",
        "model" => "claude-3",
        "mcp_servers" => {
          "valid_server" => {
            "type" => "stdio",
            "command" => "test",
          },
          "invalid_server" => "not a hash",
        },
      }

      definition = AgentDefinition.new("test_agent", config)

      refute_predicate(definition, :valid?)
      assert_includes(definition.errors, "Agent 'test_agent': MCP server 'invalid_server' must have a type")
    end

    def test_hooks_parsing
      config = {
        "description" => "Test agent",
        "provider" => "anthropic",
        "model" => "claude-3",
        "hooks" => {
          "post_tool_use" => [
            { "matcher" => "Write", "command" => "echo done" },
          ],
          "stop" => ["echo stopping"],
        },
      }

      definition = AgentDefinition.new("test_agent", config)

      assert_predicate(definition, :valid?)
      assert_equal(2, definition.hooks.keys.length)
      assert_includes(definition.hooks.keys, "post_tool_use")
      assert_includes(definition.hooks.keys, "stop")
    end

    def test_reports_parsing
      config = {
        "description" => "Test agent",
        "provider" => "anthropic",
        "model" => "claude-3",
        "reports" => ["agent1", "agent2"],
      }

      definition = AgentDefinition.new("test_agent", config)

      assert_predicate(definition, :valid?)
      assert_equal(["agent1", "agent2"], definition.reports)
    end

    def test_default_path
      config = {
        "description" => "Test agent",
        "provider" => "anthropic",
        "model" => "claude-3",
      }

      definition = AgentDefinition.new("test_agent", config)

      assert_equal(".", definition.path)
    end
  end
end

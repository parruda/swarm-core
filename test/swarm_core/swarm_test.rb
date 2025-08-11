# frozen_string_literal: true

require "test_helper"

module SwarmCore
  class SwarmTest < Minitest::Test
    extend ActiveSupport::Testing::Declarative

    def setup
      @valid_yaml = <<~YAML
        version: 2
        swarm:
          name: Test Swarm
          leader: lead_agent
          before_start:
            - echo "Starting swarm"
          agents:
            lead_agent:
              description: Lead agent
              provider: anthropic
              model: claude-3
              reports:
                - child_agent
            child_agent:
              description: Child agent
              provider: openai
              model: gpt-4
              reports:
                - grandchild_agent
            grandchild_agent:
              description: Grandchild agent
              provider: google
              model: gemini
      YAML
    end

    test "valid swarm initialization" do
      swarm = Swarm.new(@valid_yaml)

      assert_predicate(swarm, :valid?)
      assert_empty(swarm.errors)
      assert_equal("Test Swarm", swarm.name)
      assert_equal(2, swarm.version)
      assert_equal("lead_agent", swarm.leader_name)
      assert_equal(["echo \"Starting swarm\""], swarm.before_start)
      assert_equal(3, swarm.agent_definitions.length)
    end

    test "invalid yaml syntax" do
      invalid_yaml = "invalid: yaml: content:"
      swarm = Swarm.new(invalid_yaml)

      refute_predicate(swarm, :valid?)
      assert(swarm.errors.any? { |e| e.include?("YAML syntax error") })
    end

    test "missing version" do
      yaml = <<~YAML
        swarm:
          name: Test Swarm
          agents:
            test_agent:
              description: Test
              provider: anthropic
              model: claude
      YAML

      swarm = Swarm.new(yaml)

      refute_predicate(swarm, :valid?)
      assert_includes(swarm.errors, "version is required")
    end

    test "invalid version" do
      yaml = @valid_yaml.sub("version: 2", "version: 1")
      swarm = Swarm.new(yaml)

      refute_predicate(swarm, :valid?)
      assert_includes(swarm.errors, "Only version 2 is supported, got: 1")
    end

    test "missing swarm name" do
      yaml = @valid_yaml.sub("name: Test Swarm", "")
      swarm = Swarm.new(yaml)

      refute_predicate(swarm, :valid?)
      assert_includes(swarm.errors, "swarm.name is required")
    end

    test "undefined leader" do
      yaml = @valid_yaml.sub("leader: lead_agent", "leader: non_existent")
      swarm = Swarm.new(yaml)

      refute_predicate(swarm, :valid?)
      assert_includes(swarm.errors, "Leader 'non_existent' is not defined in agents")
    end

    test "undefined report agent" do
      yaml = @valid_yaml.sub("grandchild_agent", "non_existent_agent")
      swarm = Swarm.new(yaml)

      refute_predicate(swarm, :valid?)
      assert(swarm.errors.any? { |e| e.include?("reports to undefined agent 'non_existent_agent'") })
    end

    test "circular dependency detection" do
      yaml = <<~YAML
        version: 2
        swarm:
          name: Test Swarm
          agents:
            agent_a:
              description: Agent A
              provider: anthropic
              model: claude
              reports:
                - agent_b
            agent_b:
              description: Agent B
              provider: anthropic
              model: claude
              reports:
                - agent_a
      YAML

      swarm = Swarm.new(yaml)

      refute_predicate(swarm, :valid?)
      assert(swarm.errors.any? { |e| e.include?("Circular dependency detected") })
    end

    test "agent definition errors propagation" do
      yaml = <<~YAML
        version: 2
        swarm:
          name: Test Swarm
          agents:
            invalid_agent:
              description: Test
              provider: invalid_provider
              model: some-model
      YAML

      swarm = Swarm.new(yaml)

      refute_predicate(swarm, :valid?)
      assert(swarm.errors.any? { |e| e.include?("Invalid provider") })
    end

    test "start with valid swarm" do
      # Stub SystemUtils for testing
      SystemUtils.stub(:execute_command, true) do
        swarm = Swarm.new(@valid_yaml)

        assert(swarm.start)
        assert(swarm.leader_instance)
        assert_equal("lead_agent", swarm.leader_instance.name)
        assert_equal(3, swarm.active_agents.length) # leader + child + grandchild
      end
    end

    test "start with invalid swarm" do
      yaml = @valid_yaml.sub("version: 2", "version: 1")
      swarm = Swarm.new(yaml)

      refute(swarm.start)
      assert_nil(swarm.leader_instance)
      assert_empty(swarm.active_agents)
    end

    test "start with failed before start command" do
      # Stub SystemUtils to simulate command failure
      SystemUtils.stub(:execute_command, false) do
        swarm = Swarm.new(@valid_yaml)

        refute(swarm.start)
        assert(swarm.errors.any? { |e| e.include?("Failed to start swarm") })
      end
    end

    test "spawn agent" do
      SystemUtils.stub(:execute_command, true) do
        swarm = Swarm.new(@valid_yaml)
        swarm.start

        # Spawn a new instance of child_agent
        agent = swarm.spawn_agent("child_agent")

        assert(agent)
        assert_equal("child_agent", agent.name)
        assert_equal(swarm.leader_instance, agent.parent)
        assert_includes(swarm.active_agents, agent)
      end
    end

    test "spawn undefined agent" do
      SystemUtils.stub(:execute_command, true) do
        swarm = Swarm.new(@valid_yaml)
        swarm.start

        agent = swarm.spawn_agent("non_existent")

        assert_nil(agent)
      end
    end

    test "find agent" do
      SystemUtils.stub(:execute_command, true) do
        swarm = Swarm.new(@valid_yaml)
        swarm.start

        leader = swarm.leader_instance
        found = swarm.find_agent(leader.id)

        assert_equal(leader, found)

        # Find child agent
        child = leader.children.first
        found_child = swarm.find_agent(child.id)

        assert_equal(child, found_child)

        # Non-existent agent
        assert_nil(swarm.find_agent("non-existent-id"))
      end
    end

    test "agent tree" do
      SystemUtils.stub(:execute_command, true) do
        swarm = Swarm.new(@valid_yaml)
        swarm.start

        tree = swarm.agent_tree

        assert(tree)
        assert_equal(swarm.leader_instance.id, tree[:id])
        assert_equal("lead_agent", tree[:name])
        assert_equal(1, tree[:children].length)

        child_tree = tree[:children].first

        assert_equal("child_agent", child_tree[:name])
        assert_equal(1, child_tree[:children].length)

        grandchild_tree = child_tree[:children].first

        assert_equal("grandchild_agent", grandchild_tree[:name])
        assert_empty(grandchild_tree[:children])
      end
    end

    test "agent tree without leader" do
      yaml = <<~YAML
        version: 2
        swarm:
          name: Test Swarm
          agents:
            test_agent:
              description: Test
              provider: anthropic
              model: claude
      YAML

      swarm = Swarm.new(yaml)

      assert_nil(swarm.agent_tree)
    end

    test "circular dependency with non-existent agent in chain" do
      yaml = <<~YAML
        version: 2
        swarm:
          name: Test Swarm
          agents:
            agent_a:
              description: Agent A
              provider: anthropic
              model: claude
              reports:
                - non_existent
      YAML

      swarm = Swarm.new(yaml)

      refute_predicate(swarm, :valid?)
      # Should have error about undefined agent
      assert(swarm.errors.any? { |e| e.include?("reports to undefined agent 'non_existent'") })
    end

    test "parse yaml with non-hash structure" do
      yaml = "just a string"
      swarm = Swarm.new(yaml)

      refute_predicate(swarm, :valid?)
      assert_includes(swarm.errors, "Invalid YAML structure: must be a Hash")
    end

    test "spawn agent returns nil for undefined agent" do
      SystemUtils.stub(:execute_command, true) do
        swarm = Swarm.new(@valid_yaml)
        swarm.start
        result = swarm.spawn_agent("undefined_agent")

        assert_nil(result)
      end
    end

    test "validate leader with nil leader name" do
      yaml = <<~YAML
        version: 2
        swarm:
          name: Test Swarm
          agents:
            test_agent:
              description: Test
              provider: anthropic
              model: claude
      YAML

      swarm = Swarm.new(yaml)

      # Should be valid with no leader
      assert_predicate(swarm, :valid?)
    end

    test "initialize leader with no leader name" do
      yaml = <<~YAML
        version: 2
        swarm:
          name: Test Swarm
          agents:
            test_agent:
              description: Test
              provider: anthropic
              model: claude
      YAML

      SystemUtils.stub(:execute_command, true) do
        swarm = Swarm.new(yaml)

        assert(swarm.start)
        assert_nil(swarm.leader_instance)
        assert_empty(swarm.active_agents)
      end
    end

    test "validate path with nil path" do
      config = {
        "description" => "Test agent",
        "provider" => "anthropic",
        "model" => "claude-3",
        "path" => nil,
      }

      definition = AgentDefinition.new("test_agent", config)

      assert_predicate(definition, :valid?)
      assert_equal(".", definition.path) # Should default to "."
    end

    test "multiple reports initialization" do
      yaml = <<~YAML
        version: 2
        swarm:
          name: Test Swarm
          leader: lead_agent
          agents:
            lead_agent:
              description: Lead agent
              provider: anthropic
              model: claude
              reports:
                - child1
                - child2
            child1:
              description: First child
              provider: openai
              model: gpt-4
            child2:
              description: Second child
              provider: google
              model: gemini
      YAML

      SystemUtils.stub(:execute_command, true) do
        swarm = Swarm.new(yaml)
        swarm.start

        assert_equal(3, swarm.active_agents.length)
        assert_equal(2, swarm.leader_instance.children.length)

        child_names = swarm.leader_instance.children.map(&:name)

        assert_includes(child_names, "child1")
        assert_includes(child_names, "child2")
      end
    end

    test "initialize reports with missing report definition" do
      # This tests the branch where report_definition is nil in initialize_reports
      yaml = <<~YAML
        version: 2
        swarm:
          name: Test Swarm
          leader: lead_agent
          agents:
            lead_agent:
              description: Lead agent
              provider: anthropic
              model: claude
      YAML

      SystemUtils.stub(:execute_command, true) do
        swarm = Swarm.new(yaml)

        # Manually add a report that doesn't have a definition
        swarm.agent_definitions["lead_agent"].instance_variable_set(:@reports, ["non_existent"])

        assert(swarm.start)
        # Should still start successfully, just skip the missing report
        assert(swarm.leader_instance)
        assert_empty(swarm.leader_instance.children)
      end
    end
    test "stubbing SystemUtils for testing" do
      # Demonstrate how to stub SystemUtils for testing
      commands_executed = []

      SystemUtils.stub(:execute_command, ->(cmd) {
        commands_executed << cmd
        true
      }) do
        swarm = Swarm.new(@valid_yaml)
        swarm.start

        # Verify SystemUtils was called with expected commands
        assert_equal(["echo \"Starting swarm\""], commands_executed)
        assert(swarm.leader_instance)
      end
    end

    test "SystemUtils can be injected as a mock" do
      # Create a mock SystemUtils for complete control
      mock_system_utils = Class.new do
        @commands = []

        class << self
          attr_reader :commands

          def execute_command(cmd) # rubocop:disable Naming/PredicateMethod
            @commands << cmd
            cmd != "fail" # Fail if command is "fail"
          end
        end
      end

      swarm = Swarm.new(@valid_yaml, system_utils: mock_system_utils)
      swarm.start

      # Verify our mock was used
      assert_equal(["echo \"Starting swarm\""], mock_system_utils.commands)
    end
  end
end

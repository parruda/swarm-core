# frozen_string_literal: true

require "test_helper"

module SwarmCore
  class SwarmTest < Minitest::Test
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

    def test_valid_swarm_initialization
      swarm = Swarm.new(@valid_yaml)

      assert_predicate(swarm, :valid?)
      assert_empty(swarm.errors)
      assert_equal("Test Swarm", swarm.name)
      assert_equal(2, swarm.version)
      assert_equal("lead_agent", swarm.leader_name)
      assert_equal(["echo \"Starting swarm\""], swarm.before_start)
      assert_equal(3, swarm.agent_definitions.length)
    end

    def test_invalid_yaml_syntax
      invalid_yaml = "invalid: yaml: content:"
      swarm = Swarm.new(invalid_yaml)

      refute_predicate(swarm, :valid?)
      assert(swarm.errors.any? { |e| e.include?("YAML syntax error") })
    end

    def test_missing_version
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

    def test_invalid_version
      yaml = @valid_yaml.sub("version: 2", "version: 1")
      swarm = Swarm.new(yaml)

      refute_predicate(swarm, :valid?)
      assert_includes(swarm.errors, "Only version 2 is supported, got: 1")
    end

    def test_missing_swarm_name
      yaml = @valid_yaml.sub("name: Test Swarm", "")
      swarm = Swarm.new(yaml)

      refute_predicate(swarm, :valid?)
      assert_includes(swarm.errors, "swarm.name is required")
    end

    def test_undefined_leader
      yaml = @valid_yaml.sub("leader: lead_agent", "leader: non_existent")
      swarm = Swarm.new(yaml)

      refute_predicate(swarm, :valid?)
      assert_includes(swarm.errors, "Leader 'non_existent' is not defined in agents")
    end

    def test_undefined_report_agent
      yaml = @valid_yaml.sub("grandchild_agent", "non_existent_agent")
      swarm = Swarm.new(yaml)

      refute_predicate(swarm, :valid?)
      assert(swarm.errors.any? { |e| e.include?("reports to undefined agent 'non_existent_agent'") })
    end

    def test_circular_dependency_detection
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

    def test_agent_definition_errors_propagation
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

    def test_start_with_valid_swarm
      swarm = Swarm.new(@valid_yaml)

      # Mock system call for before_start commands
      swarm.stub(:system, true) do
        assert(swarm.start)
        assert(swarm.leader_instance)
        assert_equal("lead_agent", swarm.leader_instance.name)
        assert_equal(3, swarm.active_agents.length) # leader + child + grandchild
      end
    end

    def test_start_with_invalid_swarm
      yaml = @valid_yaml.sub("version: 2", "version: 1")
      swarm = Swarm.new(yaml)

      refute(swarm.start)
      assert_nil(swarm.leader_instance)
      assert_empty(swarm.active_agents)
    end

    def test_start_with_failed_before_start_command
      swarm = Swarm.new(@valid_yaml)

      # Mock system call to simulate failure
      swarm.stub(:system, false) do
        refute(swarm.start)
        assert(swarm.errors.any? { |e| e.include?("Failed to start swarm") })
      end
    end

    def test_spawn_agent
      swarm = Swarm.new(@valid_yaml)

      swarm.stub(:system, true) do
        swarm.start

        # Spawn a new instance of child_agent
        agent = swarm.spawn_agent("child_agent")

        assert(agent)
        assert_equal("child_agent", agent.name)
        assert_equal(swarm.leader_instance, agent.parent)
        assert_includes(swarm.active_agents, agent)
      end
    end

    def test_spawn_undefined_agent
      swarm = Swarm.new(@valid_yaml)

      swarm.stub(:system, true) do
        swarm.start

        agent = swarm.spawn_agent("non_existent")

        assert_nil(agent)
      end
    end

    def test_find_agent
      swarm = Swarm.new(@valid_yaml)

      swarm.stub(:system, true) do
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

    def test_agent_tree
      swarm = Swarm.new(@valid_yaml)

      swarm.stub(:system, true) do
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

    def test_agent_tree_without_leader
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

    def test_multiple_reports_initialization
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

      swarm = Swarm.new(yaml)

      swarm.stub(:system, true) do
        swarm.start

        assert_equal(3, swarm.active_agents.length)
        assert_equal(2, swarm.leader_instance.children.length)

        child_names = swarm.leader_instance.children.map(&:name)

        assert_includes(child_names, "child1")
        assert_includes(child_names, "child2")
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module SwarmCore
  class AgentTest < Minitest::Test
    def setup
      @definition = AgentDefinition.new("test_agent", {
        "description" => "Test agent",
        "provider" => "anthropic",
        "model" => "claude-3",
        "reports" => ["child_agent"],
      })

      @child_definition = AgentDefinition.new("child_agent", {
        "description" => "Child agent",
        "provider" => "openai",
        "model" => "gpt-4",
      })
    end

    def test_agent_initialization
      agent = Agent.new(@definition)

      assert_match(/^[a-f0-9-]+$/, agent.id)
      assert_equal(@definition, agent.definition)
      assert_nil(agent.parent)
      assert_match(/^[a-f0-9-]+$/, agent.session_id)
      assert_empty(agent.context)
      assert_empty(agent.children)
    end

    def test_agent_with_parent
      parent = Agent.new(@definition)
      child = Agent.new(@child_definition, parent: parent)

      assert_equal(parent, child.parent)
      assert_equal(parent.session_id, child.session_id)
    end

    def test_agent_with_custom_session_id
      session_id = "custom-session-123"
      agent = Agent.new(@definition, session_id: session_id)

      assert_equal(session_id, agent.session_id)
    end

    def test_name_delegation
      agent = Agent.new(@definition)

      assert_equal("test_agent", agent.name)
    end

    def test_spawn_report
      parent = Agent.new(@definition)
      child = parent.spawn_report(@child_definition)

      assert_equal(parent, child.parent)
      assert_equal(parent.session_id, child.session_id)
      assert_includes(parent.children, child)
    end

    def test_conversation_history
      agent = Agent.new(@definition)

      agent.add_message("user", "Hello")
      agent.add_message("assistant", "Hi there")

      history = agent.conversation_history

      assert_equal(2, history.length)
      assert_equal("user", history[0][:role])
      assert_equal("Hello", history[0][:content])
      assert_equal("assistant", history[1][:role])
      assert_equal("Hi there", history[1][:content])

      # Ensure it returns a copy
      history.clear

      assert_equal(2, agent.conversation_history.length)
    end

    def test_can_use_tool_delegation
      agent = Agent.new(@definition)

      # Delegates to definition
      assert(agent.can_use_tool?("Read"))
      refute(agent.can_use_tool?("Bash"))
    end

    def test_leader_check
      parent = Agent.new(@definition)
      child = Agent.new(@child_definition, parent: parent)

      assert_predicate(parent, :leader?)
      refute_predicate(child, :leader?)
    end

    def test_depth_calculation
      parent = Agent.new(@definition)
      child = parent.spawn_report(@child_definition)
      grandchild = child.spawn_report(@definition)

      assert_equal(0, parent.depth)
      assert_equal(1, child.depth)
      assert_equal(2, grandchild.depth)
    end

    def test_ancestors
      parent = Agent.new(@definition)
      child = parent.spawn_report(@child_definition)
      grandchild = child.spawn_report(@definition)

      assert_empty(parent.ancestors)
      assert_equal([parent], child.ancestors)
      assert_equal([child, parent], grandchild.ancestors)
    end

    def test_descendants
      parent = Agent.new(@definition)
      child1 = parent.spawn_report(@child_definition)
      child2 = parent.spawn_report(@child_definition)
      grandchild = child1.spawn_report(@definition)

      descendants = parent.descendants

      assert_equal(3, descendants.length)
      assert_includes(descendants, child1)
      assert_includes(descendants, child2)
      assert_includes(descendants, grandchild)
    end

    def test_find_agent
      parent = Agent.new(@definition)
      child1 = parent.spawn_report(@child_definition)
      child2 = parent.spawn_report(@child_definition)
      grandchild = child1.spawn_report(@definition)

      assert_equal(parent, parent.find_agent(parent.id))
      assert_equal(child1, parent.find_agent(child1.id))
      assert_equal(child2, parent.find_agent(child2.id))
      assert_equal(grandchild, parent.find_agent(grandchild.id))
      assert_nil(parent.find_agent("non-existent-id"))
    end

    def test_to_h
      parent = Agent.new(@definition)
      child = parent.spawn_report(@child_definition)

      parent_hash = parent.to_h

      assert_equal(parent.id, parent_hash[:id])
      assert_equal("test_agent", parent_hash[:name])
      assert_equal(parent.session_id, parent_hash[:session_id])
      assert_equal(0, parent_hash[:depth])
      assert_nil(parent_hash[:parent_id])
      assert_equal([child.id], parent_hash[:children_ids])

      child_hash = child.to_h

      assert_equal(child.id, child_hash[:id])
      assert_equal("child_agent", child_hash[:name])
      assert_equal(1, child_hash[:depth])
      assert_equal(parent.id, child_hash[:parent_id])
      assert_empty(child_hash[:children_ids])
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module SwarmCore
  class AgentTest < Minitest::Test
    extend ActiveSupport::Testing::Declarative

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

    test "agent initialization" do
      agent = Agent.new(@definition)

      assert_match(/^[a-f0-9-]+$/, agent.id)
      assert_equal(@definition, agent.definition)
      assert_nil(agent.parent)
      assert_match(/^[a-f0-9-]+$/, agent.session_id)
      assert_empty(agent.context)
      assert_empty(agent.children)
    end

    test "agent with parent" do
      parent = Agent.new(@definition)
      child = Agent.new(@child_definition, parent: parent)

      assert_equal(parent, child.parent)
      assert_equal(parent.session_id, child.session_id)
    end

    test "agent with custom session id" do
      session_id = "custom-session-123"
      agent = Agent.new(@definition, session_id: session_id)

      assert_equal(session_id, agent.session_id)
    end

    test "name delegation" do
      agent = Agent.new(@definition)

      assert_equal("test_agent", agent.name)
    end

    test "spawn report" do
      parent = Agent.new(@definition)
      child = parent.spawn_report(@child_definition)

      assert_equal(parent, child.parent)
      assert_equal(parent.session_id, child.session_id)
      assert_includes(parent.children, child)
    end

    test "conversation history" do
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

    test "can use tool delegation" do
      agent = Agent.new(@definition)

      # Delegates to definition
      assert(agent.can_use_tool?("Read"))
      refute(agent.can_use_tool?("Bash"))
    end

    test "leader check" do
      parent = Agent.new(@definition)
      child = Agent.new(@child_definition, parent: parent)

      assert_predicate(parent, :leader?)
      refute_predicate(child, :leader?)
    end

    test "depth calculation" do
      parent = Agent.new(@definition)
      child = parent.spawn_report(@child_definition)
      grandchild = child.spawn_report(@definition)

      assert_equal(0, parent.depth)
      assert_equal(1, child.depth)
      assert_equal(2, grandchild.depth)
    end

    test "ancestors" do
      parent = Agent.new(@definition)
      child = parent.spawn_report(@child_definition)
      grandchild = child.spawn_report(@definition)

      assert_empty(parent.ancestors)
      assert_equal([parent], child.ancestors)
      assert_equal([child, parent], grandchild.ancestors)
    end

    test "descendants" do
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

    test "find agent" do
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

    test "to_h" do
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
    test "dependency injection for predictable IDs and timestamps" do
      # Use fixed IDs for predictable testing
      id_counter = 0
      id_generator = -> { "test-id-#{id_counter += 1}" }

      # Use fixed time for predictable testing
      fixed_time = Time.new(2024, 1, 1, 12, 0, 0)
      time_provider = -> { fixed_time }

      agent = Agent.new(
        @definition,
        id_generator: id_generator,
        time_provider: time_provider,
      )

      assert_equal("test-id-1", agent.id)
      assert_equal("test-id-2", agent.session_id)

      agent.add_message("user", "Hello")
      history = agent.conversation_history

      assert_equal(fixed_time, history[0][:timestamp])

      # Child inherits the providers
      child = agent.spawn_report(@child_definition)

      assert_equal("test-id-3", child.id)
      assert_equal("test-id-2", child.session_id) # Inherits parent's session
    end
  end
end

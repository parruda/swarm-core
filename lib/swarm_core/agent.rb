# frozen_string_literal: true

require "securerandom"

module SwarmCore
  class Agent
    attr_reader :id, :definition, :parent, :session_id, :context, :children
    attr_accessor :id_generator, :time_provider

    def initialize(definition, parent: nil, session_id: nil, id_generator: nil, time_provider: nil)
      @id_generator = id_generator || SecureRandom.method(:uuid)
      @time_provider = time_provider || Time.method(:now)
      @id = @id_generator.call
      @definition = definition
      @parent = parent
      @session_id = session_id || parent&.session_id || @id_generator.call
      @context = {}
      @children = []
      @conversation_history = []
    end

    def name
      definition.name
    end

    def spawn_report(agent_definition)
      child = self.class.new(
        agent_definition,
        parent: self,
        session_id: session_id,
        id_generator: id_generator,
        time_provider: time_provider,
      )
      @children << child
      child
    end

    def add_message(role, content)
      @conversation_history << {
        role: role,
        content: content,
        timestamp: @time_provider.call,
      }
    end

    def conversation_history
      @conversation_history.dup
    end

    def can_use_tool?(tool_name)
      definition.can_use_tool?(tool_name)
    end

    def leader?
      parent.nil?
    end

    def depth
      parent.nil? ? 0 : parent.depth + 1
    end

    def ancestors
      return [] if parent.nil?

      [parent] + parent.ancestors
    end

    def descendants
      children + children.flat_map(&:descendants)
    end

    def find_agent(agent_id)
      return self if id == agent_id

      descendants.find { |agent| agent.id == agent_id }
    end

    def to_h
      {
        id: id,
        name: name,
        session_id: session_id,
        depth: depth,
        parent_id: parent&.id,
        children_ids: children.map(&:id),
      }
    end
  end
end

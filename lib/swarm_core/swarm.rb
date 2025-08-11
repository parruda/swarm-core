# frozen_string_literal: true

require "yaml"

module SwarmCore
  class Swarm
    attr_reader :name,
      :version,
      :leader_name,
      :before_start,
      :agent_definitions,
      :leader_instance,
      :errors

    def initialize(yaml_content)
      @errors = []
      @agent_definitions = {}
      @active_agents = {}
      parse_yaml(yaml_content)
      validate
    end

    def valid?
      @errors.empty?
    end

    def start
      return false unless valid?

      run_before_start_commands
      initialize_leader
      true
    rescue StandardError => e
      @errors << "Failed to start swarm: #{e.message}"
      false
    end

    def spawn_agent(agent_name, parent: nil)
      definition = @agent_definitions[agent_name]
      return unless definition

      parent ||= @leader_instance
      agent = Agent.new(definition, parent: parent)
      @active_agents[agent.id] = agent
      agent
    end

    def find_agent(agent_id)
      @active_agents[agent_id]
    end

    def active_agents
      @active_agents.values
    end

    def agent_tree
      return unless @leader_instance

      build_tree_structure(@leader_instance)
    end

    private

    def parse_yaml(yaml_content)
      config = YAML.safe_load(yaml_content)

      unless config.is_a?(Hash)
        @errors << "Invalid YAML structure: must be a Hash"
        return
      end

      @version = config["version"]
      swarm_config = config["swarm"] || {}

      @name = swarm_config["name"]
      @leader_name = swarm_config["leader"]
      @before_start = Array(swarm_config["before_start"])

      parse_agents(swarm_config["agents"] || {})
    rescue Psych::SyntaxError => e
      @errors << "YAML syntax error: #{e.message}"
    end

    def parse_agents(agents_config)
      agents_config.each do |agent_name, agent_config|
        definition = AgentDefinition.new(agent_name, agent_config)

        if definition.valid?
          @agent_definitions[agent_name] = definition
        else
          @errors.concat(definition.errors)
        end
      end
    end

    def validate
      validate_version
      validate_swarm_name
      validate_leader
      validate_agent_reports
      validate_circular_dependencies
    end

    def validate_version
      if @version.nil?
        @errors << "version is required"
      elsif @version != 2
        @errors << "Only version 2 is supported, got: #{@version}"
      end
    end

    def validate_swarm_name
      if @name.nil? || @name.empty?
        @errors << "swarm.name is required"
      end
    end

    def validate_leader
      return if @leader_name.nil?

      unless @agent_definitions.key?(@leader_name)
        @errors << "Leader '#{@leader_name}' is not defined in agents"
      end
    end

    def validate_agent_reports
      @agent_definitions.each do |agent_name, definition|
        definition.reports.each do |report_name|
          unless @agent_definitions.key?(report_name)
            @errors << "Agent '#{agent_name}' reports to undefined agent '#{report_name}'"
          end
        end
      end
    end

    def validate_circular_dependencies
      @agent_definitions.each do |agent_name, _|
        if has_circular_dependency?(agent_name, [])
          @errors << "Circular dependency detected for agent '#{agent_name}'"
        end
      end
    end

    def has_circular_dependency?(agent_name, visited)
      return true if visited.include?(agent_name)

      definition = @agent_definitions[agent_name]
      return false unless definition

      visited += [agent_name]
      definition.reports.any? { |report| has_circular_dependency?(report, visited) }
    end

    def run_before_start_commands
      @before_start.each do |command|
        system(command) or raise "Command failed: #{command}"
      end
    end

    def initialize_leader
      return unless @leader_name

      leader_definition = @agent_definitions[@leader_name]
      @leader_instance = Agent.new(leader_definition)
      @active_agents[@leader_instance.id] = @leader_instance

      # Initialize report agents
      initialize_reports(@leader_instance)
    end

    def initialize_reports(parent_agent)
      parent_agent.definition.reports.each do |report_name|
        report_definition = @agent_definitions[report_name]
        next unless report_definition

        child = parent_agent.spawn_report(report_definition)
        @active_agents[child.id] = child

        # Recursively initialize reports
        initialize_reports(child)
      end
    end

    def build_tree_structure(agent)
      {
        id: agent.id,
        name: agent.name,
        children: agent.children.map { |child| build_tree_structure(child) },
      }
    end
  end
end

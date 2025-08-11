# frozen_string_literal: true

module SwarmCore
  class AgentDefinition
    REQUIRED_FIELDS = [:description, :provider, :model].freeze
    VALID_PROVIDERS = ["anthropic", "openai", "google"].freeze
    DEFAULT_TOOLS = ["Read", "Glob", "LS", "Grep", "TodoWrite", "Task"].freeze

    attr_reader :name,
      :description,
      :provider,
      :model,
      :path,
      :system_prompt,
      :allowed_tools,
      :disallowed_tools,
      :reports,
      :hooks,
      :mcp_servers,
      :errors

    def initialize(name, config)
      @name = name
      @errors = []
      parse_config(config)
      validate
    end

    def valid?
      @errors.empty?
    end

    def can_use_tool?(tool_name)
      return false if disallowed_tool?(tool_name)
      return true if DEFAULT_TOOLS.include?(tool_name)

      allowed_tool?(tool_name)
    end

    private

    def parse_config(config)
      @description = config["description"]
      @provider = config["provider"]
      @model = config["model"]
      @path = config["path"] || "."
      @system_prompt = config["system_prompt"]
      @allowed_tools = parse_tools(config["allowed_tools"] || [])
      @disallowed_tools = parse_tools(config["disallowed_tools"] || [])
      @reports = Array(config["reports"])
      @hooks = config["hooks"] || {}
      @mcp_servers = config["mcp_servers"] || {}
    end

    def parse_tools(tools_config)
      tools_config.map do |tool|
        case tool
        when String
          { name: tool, matcher: nil }
        when Hash
          { name: tool["tool"], matcher: tool["matcher"] }
        else
          @errors << "Invalid tool configuration: #{tool.inspect}"
          nil
        end
      end.compact
    end

    def validate
      validate_required_fields
      validate_provider
      validate_path
      validate_reports
      validate_mcp_servers
    end

    def validate_required_fields
      REQUIRED_FIELDS.each do |field|
        value = instance_variable_get("@#{field}")
        if value.nil? || (value.respond_to?(:empty?) && value.empty?)
          @errors << "Agent '#{name}': #{field} is required"
        end
      end
    end

    def validate_provider
      return if @provider.nil?

      unless VALID_PROVIDERS.include?(@provider)
        @errors << "Agent '#{name}': Invalid provider '#{@provider}'. Must be one of: #{VALID_PROVIDERS.join(", ")}"
      end
    end

    def validate_path
      nil if @path.nil? || @path.empty?
      # Path validation could be expanded based on requirements
    end

    def validate_reports
      # Reports validation will check against other agents in the swarm context
    end

    def validate_mcp_servers
      @mcp_servers.each do |server_name, config|
        unless config.is_a?(Hash) && config["type"]
          @errors << "Agent '#{name}': MCP server '#{server_name}' must have a type"
        end
      end
    end

    def allowed_tool?(tool_name)
      @allowed_tools.any? { |tool| tool[:name] == tool_name }
    end

    def disallowed_tool?(tool_name)
      @disallowed_tools.any? { |tool| tool[:name] == tool_name }
    end
  end
end

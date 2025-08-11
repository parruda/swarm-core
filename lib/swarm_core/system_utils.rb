# frozen_string_literal: true

require "open3"

module SwarmCore
  # Utility class for system command execution
  # Provides robust command execution with STDOUT, STDERR capture and streaming
  class SystemUtils
    # Result object for command execution
    CommandResult = Struct.new(:stdout, :stderr, :exit_status, :success?, keyword_init: true) do
      def to_s
        stdout
      end
    end

    class << self
      # Execute a command and wait for it to complete
      # @param command [String, Array] the command to execute
      # @param chdir [String, nil] directory to execute command in
      # @return [Boolean] true if command succeeded (exit status 0)
      def execute_command(command, chdir: nil) # rubocop:disable Naming/PredicateMethod
        result = capture_command(command, chdir: chdir)
        result.success?
      end

      # Execute a command and capture its output
      # @param command [String, Array] the command to execute
      # @param chdir [String, nil] directory to execute command in
      # @return [CommandResult] result object with stdout, stderr, and exit status
      def capture_command(command, chdir: nil)
        options = chdir ? { chdir: chdir } : {}
        stdout, stderr, status = Open3.capture3(*command_to_array(command), options)

        CommandResult.new(
          stdout: stdout,
          stderr: stderr,
          exit_status: status.exitstatus,
          success?: status.success?,
        )
      rescue StandardError => e
        CommandResult.new(
          stdout: "",
          stderr: e.message,
          exit_status: -1,
          success?: false,
        )
      end

      # Execute a command and stream output in real-time
      # @param command [String, Array] the command to execute
      # @param chdir [String, nil] directory to execute command in
      # @yield [String, Symbol] output line and type (:stdout or :stderr)
      # @return [CommandResult] result object with captured output
      def stream_command(command, chdir: nil, &block)
        stdout_lines = []
        stderr_lines = []
        exit_status = nil

        options = chdir ? { chdir: chdir } : {}
        Open3.popen3(*command_to_array(command), options) do |_stdin, stdout, stderr, wait_thread|
          # Create threads to read stdout and stderr simultaneously
          stdout_thread = Thread.new do
            stdout.each_line do |line|
              stdout_lines << line
              yield(line, :stdout) if block_given?
            end
          end

          stderr_thread = Thread.new do
            stderr.each_line do |line|
              stderr_lines << line
              yield(line, :stderr) if block_given?
            end
          end

          # Wait for both threads to complete
          stdout_thread.join
          stderr_thread.join

          # Get exit status
          exit_status = wait_thread.value.exitstatus
        end

        CommandResult.new(
          stdout: stdout_lines.join,
          stderr: stderr_lines.join,
          exit_status: exit_status,
          success?: exit_status == 0,
        )
      rescue StandardError => e
        CommandResult.new(
          stdout: stdout_lines.join,
          stderr: stderr_lines.join + e.message,
          exit_status: -1,
          success?: false,
        )
      end

      # Execute a command with a timeout
      # @param command [String, Array] the command to execute
      # @param timeout [Numeric] timeout in seconds
      # @param chdir [String, nil] directory to execute command in
      # @return [CommandResult] result object
      def execute_with_timeout(command, timeout:, chdir: nil)
        require "timeout"

        Timeout.timeout(timeout) do
          capture_command(command, chdir: chdir)
        end
      rescue Timeout::Error
        # Try to kill the process if it's still running
        CommandResult.new(
          stdout: "",
          stderr: "Command timed out after #{timeout} seconds",
          exit_status: -1,
          success?: false,
        )
      end

      # Check if a command exists in the system PATH
      # @param command [String] the command name to check
      # @return [Boolean] true if command exists in PATH
      def command_exists?(command)
        # Use 'command -v' which is POSIX compliant and works in sh/bash/zsh
        result = capture_command(["sh", "-c", "command -v #{command}"])
        result.success?
      end

      # Get the full path of a command
      # @param command [String] the command name
      # @return [String, nil] full path to command or nil if not found
      def which(command)
        result = capture_command(["sh", "-c", "command -v #{command}"])
        result.success? ? result.stdout.strip : nil
      end

      private

      # Convert a command to an array format for Open3
      # @param command [String, Array] the command
      # @return [Array] command as array
      def command_to_array(command)
        case command
        when String
          # Use shell to handle complex commands with pipes, redirects, etc.
          ["sh", "-c", command]
        when Array
          command
        else
          raise ArgumentError, "Command must be a String or Array"
        end
      end
    end
  end
end

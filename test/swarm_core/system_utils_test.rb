# frozen_string_literal: true

require "test_helper"

module SwarmCore
  class SystemUtilsTest < Minitest::Test
    extend ActiveSupport::Testing::Declarative

    test "execute_command returns true for successful command" do
      result = SystemUtils.execute_command("echo 'test'")

      assert(result)
    end

    test "execute_command returns false for failed command" do
      result = SystemUtils.execute_command("exit 1")

      refute(result)
    end

    test "capture_command captures stdout" do
      result = SystemUtils.capture_command("echo 'hello world'")

      assert_predicate(result, :success?)
      assert_equal("hello world\n", result.stdout)
      assert_empty(result.stderr)
      assert_equal(0, result.exit_status)
    end

    test "capture_command captures stderr" do
      result = SystemUtils.capture_command("echo 'error' >&2")

      assert_predicate(result, :success?)
      assert_empty(result.stdout)
      assert_equal("error\n", result.stderr)
      assert_equal(0, result.exit_status)
    end

    test "capture_command captures both stdout and stderr" do
      result = SystemUtils.capture_command("echo 'output'; echo 'error' >&2")

      assert_predicate(result, :success?)
      assert_equal("output\n", result.stdout)
      assert_equal("error\n", result.stderr)
    end

    test "capture_command handles exit status correctly" do
      result = SystemUtils.capture_command("exit 42")

      refute_predicate(result, :success?)
      assert_equal(42, result.exit_status)
    end

    test "capture_command accepts array format" do
      result = SystemUtils.capture_command(["echo", "hello world"])

      assert_predicate(result, :success?)
      assert_equal("hello world\n", result.stdout)
    end

    test "capture_command with chdir option" do
      Dir.mktmpdir do |tmpdir|
        # Create a test file in tmpdir
        File.write(File.join(tmpdir, "test.txt"), "content")

        # Run ls command in that directory
        result = SystemUtils.capture_command("ls", chdir: tmpdir)

        assert_predicate(result, :success?)
        assert_includes(result.stdout, "test.txt")
      end
    end

    test "stream_command streams output line by line" do
      stdout_lines = []
      stderr_lines = []

      result = SystemUtils.stream_command("echo 'line1'; echo 'line2'; echo 'error' >&2") do |line, type|
        if type == :stdout
          stdout_lines << line
        else
          stderr_lines << line
        end
      end

      assert_predicate(result, :success?)
      assert_equal(["line1\n", "line2\n"], stdout_lines)
      assert_equal(["error\n"], stderr_lines)
      assert_equal("line1\nline2\n", result.stdout)
      assert_equal("error\n", result.stderr)
    end

    test "stream_command without block still captures output" do
      result = SystemUtils.stream_command("echo 'test'")

      assert_predicate(result, :success?)
      assert_equal("test\n", result.stdout)
    end

    test "execute_with_timeout completes within timeout" do
      result = SystemUtils.execute_with_timeout("echo 'fast'", timeout: 1)

      assert_predicate(result, :success?)
      assert_equal("fast\n", result.stdout)
    end

    test "execute_with_timeout times out for slow commands" do
      result = SystemUtils.execute_with_timeout("sleep 2", timeout: 0.1)

      refute_predicate(result, :success?)
      assert_equal(-1, result.exit_status)
      assert_includes(result.stderr, "timed out")
    end

    test "command_exists? returns true for existing commands" do
      assert(SystemUtils.command_exists?("echo"))
      assert(SystemUtils.command_exists?("ls"))
    end

    test "command_exists? returns false for non-existing commands" do
      refute(SystemUtils.command_exists?("this_command_does_not_exist_12345"))
    end

    test "which returns path for existing command" do
      path = SystemUtils.which("ls")

      assert(path)
      # 'ls' should return an actual path, not just the command name
      assert_includes(path, "ls")
    end

    test "which returns nil for non-existing command" do
      path = SystemUtils.which("this_command_does_not_exist_12345")

      assert_nil(path)
    end

    test "CommandResult to_s returns stdout" do
      result = SystemUtils::CommandResult.new(
        stdout: "output",
        stderr: "error",
        exit_status: 0,
        success?: true,
      )

      assert_equal("output", result.to_s)
    end

    test "capture_command handles exceptions gracefully" do
      # Test with invalid command that causes exception
      SystemUtils.stub(:command_to_array, ->(_) { raise "Test error" }) do
        result = SystemUtils.capture_command("test")

        refute_predicate(result, :success?)
        assert_equal(-1, result.exit_status)
        assert_includes(result.stderr, "Test error")
      end
    end

    test "stream_command handles exceptions gracefully" do
      # Mock Open3.popen3 to raise an error
      Open3.stub(:popen3, ->(*_args) { raise "Stream error" }) do
        result = SystemUtils.stream_command("test")

        refute_predicate(result, :success?)
        assert_equal(-1, result.exit_status)
        assert_includes(result.stderr, "Stream error")
      end
    end
  end
end

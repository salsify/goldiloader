# frozen_string_literal: true

class BenchmarkServer
  READY = 'ready'
  STEP = 'step'
  STEP_COMMAND_PREFIX_LENGTH = STEP.length + 1
  OK = 'ok'
  SHUTDOWN = 'shutdown'

  def self.start(**options)
    server = new(**options)
    server.start
    server
  end

  def initialize(step:, setup: nil)
    @step = step
    @setup = setup
  end

  def start
    @read_pipe, child_write_pipe = IO.pipe
    child_read_pipe, @write_pipe = IO.pipe

    @child_pid = fork do
      @read_pipe.close
      @write_pipe.close

      @setup.call if @setup

      child_write_pipe.puts(READY)

      loop do
        command = child_read_pipe.readline.rstrip
        if command == SHUTDOWN
          exit
        elsif command.start_with?(STEP)
          iterations = command.from(STEP_COMMAND_PREFIX_LENGTH).to_i
          if @step.arity > 0
            @step.call(iterations)
          else
            iterations.times { @step.call }
          end
          child_write_pipe.puts(OK)
        else
          STDERR.puts("Unexpected command: #{command}")
          exit(1)
        end
      end
    end

    child_write_pipe.close
    child_read_pipe.close

    expect_response!(READY)
  end

  def step(iterations = 1)
    @write_pipe.puts("#{STEP} #{iterations}")
    expect_response!(OK)
  end

  def shutdown
    @write_pipe.puts(SHUTDOWN)
    @read_pipe.close
    @write_pipe.close

    Process.waitpid(@child_pid)
  end

  private

  def expect_response!(expected_response)
    result = @read_pipe.readline.rstrip
    raise "Expected child response '#{expected_response}' but got '#{result}'" unless result == expected_response
  end
end

# frozen_string_literal: true

class ExperimentServer
  READY = 'ready'
  STEP = 'step'
  STEP_COMMAND_PREFIX_LENGTH = STEP.length + 1
  OK = 'ok'
  SHUTDOWN = 'shutdown'

  def self.start(step:, setup: nil)
    read_pipe, child_write_pipe = IO.pipe
    child_read_pipe, write_pipe = IO.pipe

    pid = fork do
      read_pipe.close
      write_pipe.close

      run(step: step, setup: setup, read_pipe: child_read_pipe, write_pipe: child_write_pipe)
    end

    child_write_pipe.close
    child_read_pipe.close

    new(read_pipe: read_pipe, write_pipe: write_pipe, pid: pid)
  end

  def self.run(step:, read_pipe:, write_pipe:, setup: nil)
    setup.call if setup

    write_pipe.puts(READY)

    loop do
      command = read_pipe.readline.rstrip
      if command == SHUTDOWN
        exit
      elsif command.start_with?(STEP)
        iterations = command.from(STEP_COMMAND_PREFIX_LENGTH).to_i
        if step.arity > 0
          step.call(iterations)
        else
          iterations.times { step.call }
        end
        write_pipe.puts(OK)
      else
        warn("Unexpected command: #{command}")
        exit(1)
      end
    end
  end

  def initialize(read_pipe:, write_pipe:, pid:)
    @read_pipe = read_pipe
    @write_pipe = write_pipe
    @pid = pid

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

    Process.waitpid(@pid)
  end

  private

  def expect_response!(expected_response)
    result = @read_pipe.readline.rstrip
    raise "Expected child response '#{expected_response}' but got '#{result}'" unless result == expected_response
  end
end

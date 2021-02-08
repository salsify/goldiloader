# frozen_string_literal: true

require_relative 'experiment_server'
require 'benchmark/ips'
require 'forwardable'

module ForkingBenchmark
  extend self

  # Wraps the Benchmark in an adapter runs the test block in a forked process
  class BenchmarkAdapter
    extend Forwardable

    def_delegators :@benchmark, :time=, :warmup=, :config, :compare!

    def initialize(benchmark)
      @benchmark = benchmark
      @setups = []
      @experiement_servers = []
    end

    def report(label, setup: nil, &step)
      setups = @setups.dup
      setups << setup if setup
      wrapped_setup = Proc.new do
        setups.each(&:call)
      end
      experiement_server = ExperimentServer.start(setup: wrapped_setup, step: step)
      @experiement_servers << experiement_server
      @benchmark.report(label) do |iterations|
        experiement_server.step(iterations)
      end
    end

    def setup(&block)
      raise ArgumentError.new('No block given') unless block_given?

      @setups << block
      nil
    end

    def shutdown
      @experiement_servers.each(&:shutdown)
      nil
    end
  end

  def ips
    adapter = nil
    Benchmark.ips do |benchmark|
      adapter = BenchmarkAdapter.new(benchmark)
      yield(adapter)
    end
  ensure
    adapter.shutdown if adapter
  end
end

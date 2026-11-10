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
      @experiment_servers = {}
    end

    def report(label, setup: nil, &step)
      raise ArgumentError.new("Duplicate report label: #{label}") if @experiment_servers.key?(label)

      setups = @setups.dup
      setups << setup if setup
      wrapped_setup = Proc.new do
        setups.each(&:call)
      end
      experiment_server = ExperimentServer.start(setup: wrapped_setup, step: step)
      @experiment_servers[label] = experiment_server
      @benchmark.report(label) do |iterations|
        experiment_server.step(iterations)
      end
    end

    def setup(&block)
      raise ArgumentError.new('No block given') unless block_given?

      @setups << block
      nil
    end

    def report_allocations
      allocations = @experiment_servers.transform_values do |experiment_server|
        # Run a throwaway step to ensure the scenario has been warmed up
        experiment_server.step
        experiment_server.step.allocations
      end
      return if allocations.empty?

      fewest_allocations = allocations.values.min
      label_width = allocations.keys.map(&:length).max

      puts
      puts 'Allocations per iteration:'
      allocations.sort_by(&:last).each do |label, count|
        line = "#{label.rjust(label_width)}: #{count.to_s.rjust(8)}"
        line += " - #{format('%.2f', count / fewest_allocations.to_f)}x more" if count > fewest_allocations
        puts line
      end
      puts
      nil
    end

    def shutdown
      @experiment_servers.each_value(&:shutdown)
      nil
    end
  end

  def ips
    adapter = nil
    Benchmark.ips do |benchmark|
      adapter = BenchmarkAdapter.new(benchmark)
      yield(adapter)
    end
    adapter.report_allocations
  ensure
    adapter.shutdown if adapter
  end
end

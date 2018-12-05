# frozen_string_literal: true

require_relative 'benchmark_server'
require 'benchmark/ips'
require 'forwardable'

module ForkingBenchmark
  extend self

  class BenchmarkProxy
    extend Forwardable

    def_delegators :@benchmark, :time=, :warmup=, :config, :compare!

    def initialize(benchmark)
      @benchmark = benchmark
      @setups = []
      @servers = []
    end

    def report(label, setup: nil, &step)
      setups = @setups.dup
      setups << setup if setup
      wrapped_setup = Proc.new do
        setups.each(&:call)
      end
      server = BenchmarkServer.start(setup: wrapped_setup, step: step)
      @servers << server
      @benchmark.report(label) do |iterations|
        server.step(iterations)
      end
    end

    def setup(&block)
      raise ArgumentError.new('No block given') unless block_given?
      @setups << block
      nil
    end

    def shutdown
      @servers.each(&:shutdown)
      nil
    end
  end

  def ips
    proxy = nil
    Benchmark.ips do |benchmark|
      proxy = BenchmarkProxy.new(benchmark)
      yield(proxy)
    end
  ensure
    proxy.shutdown if proxy
  end
end

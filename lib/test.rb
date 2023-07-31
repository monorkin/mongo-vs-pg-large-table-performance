# frozen_string_literal: true

require "active_support/inflector"
require "parallel"
require "benchmark"
require "active_support/tagged_logging"
require "mongo"
require "mongoid"
require "active_record"
require "activerecord-copy"
require "pg"
require "uri"
require "forwardable"

class Test
  extend Forwardable

  BASE_RECORD_COUNT = 100_000_000
  WRITE_TEST_RECORD_COUNT = 100_000
  CONCURRENCY = 50
  TEST_CASES = {
    postgres: { adapter: :postgres, url: ENV["POSTGRES_URL"] },
    mongo_db: { adapter: :mongo_db, url: ENV["MONGODB_URL"] }
  }.freeze

  attr_accessor :cases, :sync, :base_record_count, :write_test_record_count, :concurrency

  def_delegator 'self.class', :logger

  def initialize(cases: nil, sync: true,
                 base_record_count: nil,
                 write_test_record_count: nil, concurrency: nil)
    self.cases = (cases || TEST_CASES).with_indifferent_access
    self.sync = sync
    self.base_record_count = base_record_count || BASE_RECORD_COUNT
    self.write_test_record_count = write_test_record_count || WRITE_TEST_RECORD_COUNT
    self.concurrency = concurrency || CONCURRENCY
  end

  def run
    work = proc do |name, config|
      raise "No adapter for #{name} in #{config}" if config[:adapter].blank?

      case_name = "TestCase::#{config[:adapter].to_s.camelize(:upper)}"
      case_name.constantize.new(test: self, name: name, url: config[:url]).run
    end

    if sync
      cases.map(&work)
    else
      Parallel.map(cases, &work)
    end
  end

  def random_thing_values(count = 1_000_000)
    types = %w[Event User Home Component]

    count.times.lazy.map do |i|
      {
        url: "https://example.com/#{SecureRandom.hex(5)}-#{i}",
        secret: SecureRandom.hex(256),
        creator_id: rand(1..100_000_000),
        owner_id: rand(1..100_000_000),
        related_to_id: rand(1..100_000_000),
        related_to_type: types.sample,
        logged_at: (-100..100).to_a.sample.minutes.ago,
        created_at: (-100..100).to_a.sample.minutes.ago,
        updated_at: (-100..100).to_a.sample.minutes.ago
      }
    end
  end

  class << self
    attr_reader :debug

    def logger
      @logger ||= ActiveSupport::TaggedLogging.new(Logger.new(STDOUT)).tap do |logger|
        configure_logger_level(logger)
      end
    end

    def debug=(value)
      @debug = value
      configure_logger_level(logger)
    end

    def debug?
      !!debug
    end

    private

    def configure_logger_level(logger)
      logger.level = debug? ? Logger::DEBUG : Logger::INFO
    end
  end
end

require "zeitwerk"

loader = Zeitwerk::Loader.new
loader.push_dir(__dir__)
loader.setup

# frozen_string_literal: true

class TestCase
  BASE_RECORD_COUNT = 100_000_000
  WRITE_TEST_RECORD_COUNT = 100_000

  attr_reader :results

  def initialize
    @results = {}
  end

  def run
    logger.info "Running test case #{self.class}..."

    logger.info "Connecting to the database..."
    connect!

    logger.info "Testing bulk insertion..."
    results[:insert_time] = Benchmark.realtime { test_bulk_insert }
    logger.info "= Bulk insertion test finished in #{results[:insert_time]} ="

    logger.info "Testing concurrent read-write performance..."
    results[:concurrent_read_write_time] = Benchmark.realtime { test_concurrent_read_write }
    logger.info "= Concurrent read-write test finished in #{results[:concurrent_read_write_time]} ="

    self
  end

  def connect!
    raise NotImplementedError
  end

  def insert_records(count = 10_000)
    raise NotImplementedError
  end

  def insert_record
    raise NotImplementedError
  end

  def find_last_by(sort)
    raise NotImplementedError
  end

  def test_bulk_insert
    batch_size = 1_000
    target_record_count = BASE_RECORD_COUNT
    batch_count = target_record_count / batch_size

    batch_count.times do |i|
      logger.debug "Inserting batch #{i}/#{batch_count} of #{batch_size} records..."
      insert_records(batch_size)
    end
  end

  def test_concurrent_read_write
    mutex = Mutex.new

    stop_reading = false

    reader = Thread.new do
      [
        :url, :secret, :creator_id, :owner_id,
        [:related_to_id, :related_to_type], :logged_at,
        :created_at, :updated_at
      ].cycle.each do |columns|
        break if stop_reading

        %i[asc desc].each do |direction|
          break if stop_reading

          sort = Array(columns).map { |c| [c, direction] }.to_h
          logger.debug "Reading last record by #{sort}"
          find_last_by(sort)
        end
      end
    end

    writer = Thread.new do
      mutex.synchronize do
        WRITE_TEST_RECORD_COUNT.times do |i|
          logger.debug "Writing record #{i}"
          insert_record
        end
      end
    end

    supervisor = Thread.new do
      loop do
        if mutex.try_lock
          sleep 0.01
          mutex.unlock
          next
        end

        logger.debug "Waiting for the writer to finish..."
        mutex.synchronize do
          stop_reading = true
        end

        logger.debug "Terminating reader and writer..."
        break
      end
    end

    [reader, writer, supervisor].each(&:join)
  end

  def random_thing_values(count = 1_000_000)
    types = %w[Event User Home Component]

    count.times.map do |i|
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

  def logger
    self.class.logger
  end

  def debug?
    self.class.debug?
  end

  def name
    self.class.case_name
  end

  class << self
    def logger
      @logger ||= begin
        logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))

        logger.level = debug? ? Logger::DEBUG : Logger::INFO

        logger.tagged(case_name)
      end
    end

    def debug?
      ENV["DEBUG"] == "true"
    end

    def case_name
      name.gsub(/^.*TestCase::/, "")
    end
  end
end

# frozen_string_literal: true

class TestCase
  extend Forwardable

  attr_reader :test, :results, :url, :name

  def_delegator :test, :base_record_count
  def_delegator :test, :write_test_record_count
  def_delegator :test, :random_thing_values
  def_delegator 'self.class', :logger

  def initialize(test:, name:, url:)
    @test = test
    @url = url
    @name = name
    @results = {}
  end

  def run
    logger.info "Running test case #{name} (#{self.class})..."

    logger.info "Connecting to the database..."
    connect!

    logger.info "Inserting #{test.base_record_count} records..."
    insert_base_records

    logger.info "Testing bulk insertion..."
    results[:insert_time] = Benchmark.realtime { test_bulk_insert }
    logger.info "= Bulk insertion test finished in #{results[:insert_time]} ="

    logger.info "Testing concurrent read-write performance..."
    results[:concurrent_read_write_time] = Benchmark.realtime { test_concurrent_read_write }
    logger.info "= Concurrent read-write test finished in #{results[:concurrent_read_write_time]} ="

    logger.info "Test case #{name} (#{self.class}) finished."

    logger.info "Clearing out the database..."
    clear!

    logger.info "Disconnecting from the database..."
    disconnect!

    self
  end

  def connect!
    raise NotImplementedError
  end

  def disconnect!
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

  def insert_base_records
    raise NotImplementedError
  end

  def clear!
    raise NotImplementedError
  end

  def with_connection(&block)
    block.call
  end

  def test_bulk_insert
    batch_size = 1_000
    batches = test.write_test_record_count / batch_size

    batches = 1 if batches.zero?

    batches.times do |i|
      logger.debug "Inserting batch #{i}/#{batches} of #{batch_size} records..."
      insert_records(batch_size)
    end
  end

  def test_concurrent_read_write
    mutex = Mutex.new
    counts = { read: 0, write: 0, done_write: 0 }
    stop_reading = false

    readers = test.concurrency.times.map do |i|
      Thread.new do
        mutex.synchronize { counts[:read] += 1 }
        logger.debug "Starting reader #{i}"

        with_connection do
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
              record = find_last_by(sort)
              logger.debug("Got record #{record&.id}")
            end
          end
        end
      end
    end

    writers = test.concurrency.times.map do |i|
      Thread.new do
        mutex.synchronize { counts[:write] += 1 }
        logger.debug "Starting writer #{i}"

        with_connection do
          test.write_test_record_count.times do |i|
            logger.debug "Writing record #{i}"
            insert_record
          end
        end

        mutex.synchronize { counts[:done_write] += 1 }
      end
    end

    supervisor = Thread.new do
      loop do
        if counts[:read] < test.concurrency || counts[:write] < test.concurrency
          sleep 0.01
          next
        end

        logger.debug "Waiting for the writers to finish..."
        loop do
          break if counts[:done_write] >= test.concurrency
          sleep 0.1
        end

        logger.debug "Terminating readers and writers..."
        stop_reading = true
        break
      end
    end

    [*readers, *writers, supervisor].each(&:join)
  end

  def logger
    @logger ||= test.logger.tagged(self.class.case_name).tagged(name)
  end

  class << self
    def case_name
      name.gsub(/^.*TestCase::/, "")
    end
  end
end

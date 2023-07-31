# frozen_string_literal: true

class TestCase::Postgres < TestCase
  def insert_records(count = 1_000_000)
    Thing.insert_all(random_thing_values(count))
  end

  def insert_record
    Thing.create!(random_thing_values(1).first)
  end

  def find_last_by(sort)
    Thing.order(sort).last
  end

  def connect!
    uri = self.url
    logger.debug "Connecting to #{uri}"

    url = URI(uri)
    logger.debug "Connecting to #{url.host}:#{url.port} as #{url.user} using #{url.path[1..-1]}"

    @connection = ActiveRecord::Base.establish_connection(
      adapter: "postgresql",
      host: url.host,
      port: url.port,
      username: url.user,
      password: url.password,
      database: url.path[1..-1],
      pool: test.concurrency * 4
    )
    ActiveRecord::Base.logger = logger

    ActiveRecord::Schema.define do
      create_table :things, force: true do |t|
        t.string :url
        t.text :secret
        t.bigint :creator_id, index: true
        t.bigint :owner_id, index: true
        t.bigint :related_to_id, index: true
        t.string :related_to_type, index: true
        t.datetime :logged_at, index: true
        t.timestamps index: true
      end
    end
  end

  def with_connection(&block)
    ActiveRecord::Base.connection_pool.with_connection(&block)
  end

  def insert_base_records
    headers = random_thing_values(1).first.keys

    Thing.copy_from_client(headers) do |copy|
      batch_size = 1000
      batches = (base_record_count / batch_size)

      if batches.zero?
        batches = 1
        batch_size = base_record_count
      end

      batches.times do |i|
        logger.debug "Inserting #{i}/#{batches} batch of #{batch_size} records"
        random_thing_values(batch_size).map(&:values).each do |values|
          copy << values
        end
      end
    end
  end

  def clear!
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE things")
  end

  def disconnect!
    ActiveRecord::Base.remove_connection(@connection)
  end

  class Thing < ActiveRecord::Base
  end
end

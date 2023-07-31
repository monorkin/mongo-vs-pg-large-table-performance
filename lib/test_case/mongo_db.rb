# frozen_string_literal: true

class TestCase::MongoDb < TestCase
  def insert_records(count = 1_000_000)
    Thing.collection.insert_many(random_thing_values(count), safe: true)
  end

  def insert_record
    Thing.create!(random_thing_values(1).first)
  end

  def find_last_by(sort)
    Thing.order(sort).limit(1).first
  end

  def connect!
    uri = self.url
    logger.debug "Connecting to #{uri}"

    url = URI(uri)
    logger.debug "Connecting to #{url.host}:#{url.port} as #{url.user} using #{url.path[1..-1]}"

    Mongoid.configure do |config|
      config.clients.default = {
        hosts: ["#{url.host}:#{url.port}"],
        database: url.path[1..-1],
        options: {
          user: url.user,
          password: url.password,
          auth_mech: :scram,
          auth_source: "admin",
          max_pool_size: test.concurrency * 4
        }
      }

      config.logger = logger
    end

    ::Mongoid.purge!
    Thing.create_indexes
  end

  def insert_base_records
    batch_size = 1000
    batches = (base_record_count / batch_size)

    if batches.zero?
      batches = 1
      batch_size = base_record_count
    end

    batches.times do |i|
      logger.debug "Inserting #{i}/#{batches} batch of #{batch_size} records"
      insert_records(batch_size)
    end
  end

  def clear!
    Thing.collection.delete_many
  end

  def disconnect!
    Mongoid::Clients.disconnect
  end

  class Thing
    include Mongoid::Document

    field :url, type: String
    field :secret, type: String
    field :creator_id, type: Integer
    field :owner_id, type: Integer
    field :related_to_id, type: Integer
    field :related_to_type, type: String
    field :logged_at, type: DateTime
    field :created_at, type: DateTime
    field :updated_at, type: DateTime

    index({ creator_id: 1 })
    index({ owner_id: 1 })
    index({ related_to_id: 1 })
    index({ related_to_type: 1 })
    index({ logged_at: 1 })
    index({ created_at: 1 })
    index({ updated_at: 1 })
  end
end

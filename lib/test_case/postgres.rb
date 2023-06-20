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
    # This connection will do for database-independent bug reports.
    uri = ENV["POSTGRES_URL"]
    logger.debug "Connecting to #{uri}"

    url = URI(uri)
    logger.debug "Connecting to #{url.host}:#{url.port} as #{url.user} using #{url.path[1..-1]}"

    ActiveRecord::Base.establish_connection(
      adapter: "postgresql",
      host: url.host,
      port: url.port,
      username: url.user,
      password: url.password,
      database: url.path[1..-1],
      pool: 50
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

  class Thing < ActiveRecord::Base
  end
end

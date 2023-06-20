# frozen_string_literal: true

require "active_support/inflector"
require "parallel"
require "benchmark"
require "active_support/tagged_logging"
require "mongo"
require "mongoid"
require "active_record"
require "pg"
require "uri"

class Test
  TEST_CASES = %i[postgres mongo_db].freeze

  def run(cases: TEST_CASES)
    work = proc do |c|
      case_name = "TestCase::#{c.to_s.camelize(:upper)}"
      case_name.constantize.new.run
    end

    if ENV["SYNC"] == "true"
      return cases.map(&work)
    end

    Parallel.map(cases, &work)
  end
end

require "zeitwerk"

loader = Zeitwerk::Loader.new
loader.push_dir(__dir__)
loader.setup

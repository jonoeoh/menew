# frozen_string_literal: true

require "cases/helper"

class TestAdapterWithInvalidConnection < ActiveRecord::TestCase
  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    self.use_transactional_tests = false

    class Bird < ActiveRecord::Base
    end

    def setup
      # Can't just use current adapter; sqlite3 will create a database
      # file on the fly.
      Bird.establish_connection adapter: "mysql2", database: "i_do_not_exist"
    end

    teardown do
      Bird.remove_connection_pool
    end

    test "inspect on Model class does not raise" do
      assert_equal "#{Bird.name} (call '#{Bird.name}.connection' to establish a connection)", Bird.inspect
    end
  end
end

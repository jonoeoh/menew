# encoding: utf-8

gem 'activerecord-jdbcmysql-adapter'
require 'arjdbc/mysql'

module ActiveRecord::ConnectionAdapters

  class MysqlAdapter < JdbcAdapter

    protected

    def exec_insert(sql, name, binds)
      binds = binds.dup

      # Pretend to support bind parameters
      execute sql.gsub('?') { quote(*binds.shift.reverse) }, name
    end

    def last_inserted_id(result)
      result
    end

  end
end
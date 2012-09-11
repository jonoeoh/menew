module ActiveRecord
  module Tasks # :nodoc:
    class MySQLDatabaseTasks # :nodoc:

      DEFAULT_CHARSET     = ENV['CHARSET']   || 'utf8'
      DEFAULT_COLLATION   = ENV['COLLATION'] || 'utf8_unicode_ci'
      ACCESS_DENIED_ERROR = 1045

      delegate :connection, :establish_connection, to: ActiveRecord::Base

      def initialize(configuration)
        @configuration = configuration
      end

      def create
        establish_connection configuration_without_database
        connection.create_database configuration['database'], creation_options
        establish_connection configuration
      rescue error_class => error
        raise error unless error.errno == ACCESS_DENIED_ERROR

        $stdout.print error.error
        establish_connection root_configuration_without_database
        connection.create_database configuration['database'], creation_options
        connection.execute grant_statement.gsub(/\s+/, ' ').strip
        establish_connection configuration
      rescue error_class => error
        $stderr.puts error.error
        $stderr.puts "Couldn't create database for #{configuration.inspect}, #{creation_options.inspect}"
        $stderr.puts "(If you set the charset manually, make sure you have a matching collation)" if configuration['encoding']
      end

      def drop
        establish_connection configuration
        connection.drop_database configuration['database']
      end

      def purge
        establish_connection :test
        connection.recreate_database configuration['database'], creation_options
      end

      def charset
        connection.charset
      end

      def collation
        connection.collation
      end

      def structure_dump(filename)
        establish_connection configuration
        File.open(filename, "w:utf-8") { |f| f << ActiveRecord::Base.connection.structure_dump }
      end

      def structure_load(filename)
        args = ['mysql']
        args.concat(['--user', configuration['username']]) if configuration['username']
        args << "--password=#{configuration['password']}" if configuration['password']
        args.concat(['--default-character-set', configuration['encoding']]) if configuration['encoding']
        configuration.slice('host', 'port', 'socket', 'database').each do |k, v|
          args.concat([ "--#{k}", v ]) if v
        end
        args.concat(['--execute', %{SET FOREIGN_KEY_CHECKS = 0; SOURCE #{filename}; SET FOREIGN_KEY_CHECKS = 1}])
        Kernel.system(*args)
      end

      private

      def configuration
        @configuration
      end

      def configuration_without_database
        configuration.merge('database' => nil)
      end

      def creation_options
        {
          charset:   (configuration['encoding']  || DEFAULT_CHARSET),
          collation: (configuration['collation'] || DEFAULT_COLLATION)
        }
      end

      def error_class
        case configuration['adapter']
        when /jdbc/
          require 'active_record/railties/jdbcmysql_error'
          ArJdbcMySQL::Error
        when /mysql2/
          Mysql2::Error
        else
          Mysql::Error
        end
      end

      def grant_statement
        <<-SQL
GRANT ALL PRIVILEGES ON #{configuration['database']}.*
  TO '#{configuration['username']}'@'localhost'
IDENTIFIED BY '#{configuration['password']}' WITH GRANT OPTION;
        SQL
      end

      def root_configuration_without_database
        configuration_without_database.merge(
          'username' => 'root',
          'password' => root_password
        )
      end

      def root_password
        $stdout.print "Please provide the root password for your mysql installation\n>"
        $stdin.gets.strip
      end
    end
  end
end

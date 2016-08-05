require 'abstract_unit'
require 'env_helpers'
require 'server_helpers'
require 'rails/commands/server'

class Rails::ServerTest < ActiveSupport::TestCase
  include EnvHelpers
  include ServerHelpers

  def test_environment_with_server_option
    args    = ["thin", "-e", "production"]
    options = Rails::Server::Options.new.parse!(args)
    assert_equal 'production', options[:environment]
    assert_equal 'thin', options[:server]
  end

  def test_environment_without_server_option
    args    = ["-e", "production"]
    options = Rails::Server::Options.new.parse!(args)
    assert_equal 'production', options[:environment]
    assert_nil options[:server]
  end

  def test_server_option_without_environment
    args    = ["thin"]
    options = Rails::Server::Options.new.parse!(args)
    assert_nil options[:environment]
    assert_equal 'thin', options[:server]
  end

  def test_environment_with_rails_env
    with_rack_env nil do
      with_rails_env 'production' do
        server = Rails::Server.new
        assert_equal 'production', server.options[:environment]
      end
    end
  end

  def test_environment_with_rack_env
    with_rails_env nil do
      with_rack_env 'production' do
        server = Rails::Server.new
        assert_equal 'production', server.options[:environment]
      end
    end
  end

  def test_environment_with_port
    switch_env "PORT", "1234" do
      server = Rails::Server.new
      assert_equal 1234, server.options[:Port]
    end
  end

  def test_environment_with_host
    switch_env "HOST", "1.2.3.4" do
      server = Rails::Server.new
      assert_equal "1.2.3.4", server.options[:Host]
    end
  end

  def test_actioncable_allowed_request_origins_includes_localhost_and_static_ip_during_development
    primary_ip = "2.3.4.5"
    second_ip = "10.0.0.5"
    with_rack_env 'development' do
      run_with_custom_args ["-b", primary_ip] do
        server = build_server_with_ips [primary_ip, second_ip]
        begin
          allowed_request_origins = server.app.config.action_cable.allowed_request_origins
          assert_not_includes allowed_request_origins, Regexp.new("https?:\/\/localhost:\\d+")
          assert_not_includes allowed_request_origins, Regexp.new("https?:\/\/127.0.0.1:\\d+")
          # Should include any static IP referenced with -b, even those routable on the Internet
          assert_includes allowed_request_origins, Regexp.new("https?:\/\/#{primary_ip}:\\d+")
          # Should not include any additional IP on the machine, even those not routable on the Internet
          assert_not_includes allowed_request_origins, Regexp.new("https?:\/\/#{second_ip}:\\d+")
        ensure
          teardown_app_for(server)
        end
      end
    end
  end

  def test_actioncable_allowed_request_origins_get_set_properly_when_binding_0_0_0_0_during_development
    primary_ip = "3.4.5.6"
    second_ip = "10.0.0.5"
    with_rack_env 'development' do
      run_with_custom_args ["-b", "0.0.0.0"] do
        server = build_server_with_ips [primary_ip, second_ip]
        begin
          allowed_request_origins = server.app.config.action_cable.allowed_request_origins
          assert_includes allowed_request_origins, Regexp.new("https?:\/\/localhost:\\d+")
          assert_includes allowed_request_origins, Regexp.new("https?:\/\/127.0.0.1:\\d+")
          # Should not include any IPs that are routable on the Internet
          assert_not_includes allowed_request_origins, Regexp.new("https?:\/\/#{primary_ip}:\\d+")
          # Should include all intranet IPs, i.e. those not routable on the Internet
          assert_includes allowed_request_origins, Regexp.new("https?:\/\/#{second_ip}:\\d+")
        ensure
          teardown_app_for(server)
        end
      end
    end
  end

  def test_actioncable_allowed_request_origins_are_not_set_during_production
    primary_ip = "4.5.6.7"
    with_rack_env 'production' do
      run_with_custom_args ["-b", primary_ip] do
        server = build_server_with_ips [primary_ip]
        begin
          assert_equal nil, server.app.config.action_cable.allowed_request_origins
        ensure
          teardown_app_for(server)
        end
      end
    end
  end

  def test_caching_without_option
    args = []
    options = Rails::Server::Options.new.parse!(args)
    merged_options = Rails::Server.new.default_options.merge(options)
    assert_equal nil, merged_options[:caching]
  end

  def test_caching_with_option
    args = ["--dev-caching"]
    options = Rails::Server::Options.new.parse!(args)
    assert_equal true, options[:caching]

    args = ["--no-dev-caching"]
    options = Rails::Server::Options.new.parse!(args)
    assert_equal false, options[:caching]
  end

  def test_log_stdout
    with_rack_env nil do
      with_rails_env nil do
        args    = []
        options = Rails::Server::Options.new.parse!(args)
        assert_equal true, options[:log_stdout]

        args    = ["-e", "development"]
        options = Rails::Server::Options.new.parse!(args)
        assert_equal true, options[:log_stdout]

        args    = ["-e", "production"]
        options = Rails::Server::Options.new.parse!(args)
        assert_equal false, options[:log_stdout]

        with_rack_env 'development' do
          args    = []
          options = Rails::Server::Options.new.parse!(args)
          assert_equal true, options[:log_stdout]
        end

        with_rack_env 'production' do
          args    = []
          options = Rails::Server::Options.new.parse!(args)
          assert_equal false, options[:log_stdout]
        end

        with_rails_env 'development' do
          args    = []
          options = Rails::Server::Options.new.parse!(args)
          assert_equal true, options[:log_stdout]
        end

        with_rails_env 'production' do
          args    = []
          options = Rails::Server::Options.new.parse!(args)
          assert_equal false, options[:log_stdout]
        end
      end
    end
  end

  def test_default_options
    server = Rails::Server.new
    old_default_options = server.default_options

    Dir.chdir("..") do
      assert_equal old_default_options, server.default_options
    end
  end

  def test_restart_command_contains_customized_options
    original_args = ARGV.dup
    args = ["-p", "4567"]
    ARGV.replace args

    options = Rails::Server::Options.new.parse! args
    server = Rails::Server.new options
    expected = "bin/rails server -p 4567"

    assert_equal expected, server.default_options[:restart_cmd]
  ensure
    ARGV.replace original_args
  end
end

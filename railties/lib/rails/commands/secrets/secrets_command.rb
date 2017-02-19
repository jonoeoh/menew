require "active_support"
require "active_support/core_ext/string/strip"
require "rails/generators/rails/app/app_generator"

require "rails/secrets"

module Rails
  module Command
    class SecretsCommand < Rails::Command::Base # :nodoc:
      def help
        super
        puts self.class.desc
      end

      def perform
        require_application_and_environment!

        setup
        edit
      end

      def setup
        require_application_and_environment!

        Rails::Generators::AppGenerator.new([ Rails.root ]).setup_encrypted_secrets
      end

      def edit
        require_application_and_environment!

        Rails::Secrets.read_for_editing do |tmp_path|
          watch tmp_path do
            puts "Waiting for secrets file to be saved. Abort with Ctrl-C."
            system("\$EDITOR #{tmp_path}")
          end
        end

        puts "New secrets encrypted and saved."
      rescue Interrupt
        puts "Aborted changing encrypted secrets: nothing saved."
      end

      private
        def watch(tmp_path)
          mtime, start_time = File.mtime(tmp_path), Time.now

          yield

          editor_exits_after_open = $?.success? && (Time.now - start_time) < 1
          if editor_exits_after_open
            sleep 0.250 until File.mtime(tmp_path) != mtime
          end
        end
    end
  end
end

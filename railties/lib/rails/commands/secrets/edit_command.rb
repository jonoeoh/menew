require "active_support"
require "active_support/core_ext/string/strip"

module Rails
  module Command
    module Secrets
      class EditCommand < Rails::Command::Base
        def perform
          require_application_and_environment!
          override_defaults

          ensure_encrypted_secrets_file_exists
          abort_if_missing_key

          contents = Sekrets.read(encrypted_path)

          Sekrets.tmpdir do
            IO.binwrite(decrypted_path, contents)

            system("#{Sekrets.editor} #{decrypted_path}")

            if $?.exitstatus.zero?
              Sekrets.write(encrypted_path.to_s, IO.binread(decrypted_path))
            end
          end
        end

        private
          def override_defaults
            Sekrets.env    = "RAILS_MASTER_KEY"
            Sekrets.editor = ENV["RAILS_EDITOR"] || ENV["EDITOR"]
            Sekrets.root   = Rails.root
            Sekrets.project_key = Rails.root.join("config", "secrets.yml.key")
            Sekrets.global_key  = nil # Disavow.
          end

          def ensure_encrypted_secrets_file_exists
            unless encrypted_path.exist?
              Sekrets.write(encrypted_path.to_s, <<-end_of_template.strip_heredoc)
                # Add all your production secrets here.
                production:
                  secret_key_base:
              end_of_template
            end
          end

          def abort_if_missing_key
            unless Sekrets.key_for(encrypted_path, prompt: false)
              puts "No key to decrypt secrets with!"
              puts "Assign one via `RAILS_MASTER_KEY=key bin/rails secrets:edit`."
              puts "Or put a key in config/secrets.yml.key. Ensure the file is in .gitignore!"
              exit 1
            end
          end

          def decrypted_path
            encrypted_path.basename
          end

          def encrypted_path
            Rails.root.join("config", "secrets.yml.enc")
          end
      end
    end
  end
end

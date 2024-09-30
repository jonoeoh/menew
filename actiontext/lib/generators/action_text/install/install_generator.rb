# frozen_string_literal: true

# :markup: markdown

require "pathname"
require "json"

module ActionText
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def install_javascript_dependencies
        say "Installing JavaScript dependencies", :green
        if using_bun?
          run "bun add @rails/actiontext trix"
        elsif using_node?
          run "yarn add @rails/actiontext trix"
        end
      end

      def append_javascript_dependencies
        destination = Pathname(destination_root)

        if (application_javascript_path = destination.join("app/javascript/application.js")).exist?
          insert_into_file application_javascript_path.to_s, <<~JS.strip
            import "trix"
            import "@rails/actiontext"
          JS
        else
          say <<~INSTRUCTIONS, :green
            You must import the @rails/actiontext and trix JavaScript modules in your application entrypoint.
          INSTRUCTIONS
        end

        if (importmap_path = destination.join("config/importmap.rb")).exist?
          append_to_file importmap_path.to_s, <<~RUBY.strip
            pin "trix"
            pin "@rails/actiontext", to: "actiontext.esm.js"
          RUBY
        end
      end

      def create_actiontext_files
        template "actiontext.css", "app/assets/stylesheets/actiontext.css"

        gem_root = "#{__dir__}/../../../.."

        copy_file "#{gem_root}/app/views/active_storage/blobs/_blob.html.erb",
          "app/views/active_storage/blobs/_blob.html.erb"

        copy_file "#{gem_root}/app/views/layouts/action_text/contents/_content.html.erb",
          "app/views/layouts/action_text/contents/_content.html.erb"
      end

      def enable_image_processing_gem
        if (gemfile_path = Pathname(destination_root).join("Gemfile")).exist?
          say "Ensure image_processing gem has been enabled so image uploads will work (remember to bundle!)"
          image_processing_regex = /gem ["']image_processing["']/
          if File.readlines(gemfile_path).grep(image_processing_regex).any?
            uncomment_lines gemfile_path, image_processing_regex
          else
            run "bundle add --skip-install image_processing"
          end
        end
      end

      def create_migrations
        rails_command "railties:install:migrations FROM=active_storage,action_text", inline: true
      end

      def using_js_runtime?
        @using_js_runtime ||= Pathname(destination_root).join("package.json").exist?
      end

      def using_bun?
        # Cannot assume yarn.lock has been generated yet so we look for a file known to
        # be generated by the jsbundling-rails gem
        @using_bun ||= using_js_runtime? && Pathname(destination_root).join("bun.config.js").exist?
      end

      def using_node?
        # Bun is the only runtime that _isn't_ node.
        @using_node ||= using_js_runtime? && !Pathname(destination_root).join("bun.config.js").exist?
      end

      hook_for :test_framework
    end
  end
end

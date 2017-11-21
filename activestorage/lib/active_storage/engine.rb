# frozen_string_literal: true

require "rails"
require "active_storage"

require "active_storage/previewer/pdf_previewer"
require "active_storage/previewer/video_previewer"

require "active_storage/analyzer/image_analyzer"
require "active_storage/analyzer/video_analyzer"

module ActiveStorage
  class Engine < Rails::Engine # :nodoc:
    isolate_namespace ActiveStorage

    config.active_storage = ActiveSupport::OrderedOptions.new
    config.active_storage.previewers = [ ActiveStorage::Previewer::PDFPreviewer, ActiveStorage::Previewer::VideoPreviewer ]
    config.active_storage.analyzers  = [ ActiveStorage::Analyzer::ImageAnalyzer, ActiveStorage::Analyzer::VideoAnalyzer ]

    config.eager_load_namespaces << ActiveStorage

    initializer "active_storage.configs" do
      config.after_initialize do |app|
        ActiveStorage.logger     = app.config.active_storage.logger || Rails.logger
        ActiveStorage.queue      = app.config.active_storage.queue
        ActiveStorage.previewers = app.config.active_storage.previewers || []
        ActiveStorage.analyzers  = app.config.active_storage.analyzers || []
      end
    end

    initializer "active_storage.attached" do
      require "active_storage/attached"

      ActiveSupport.on_load(:active_record) do
        extend ActiveStorage::Attached::Macros
      end
    end

    initializer "active_storage.verifier" do
      config.after_initialize do |app|
        ActiveStorage.verifier = app.message_verifier("ActiveStorage")
      end
    end

    initializer "active_storage.services" do
      config.to_prepare do
        if config_choice = Rails.configuration.active_storage.service
          configs = Rails.configuration.active_storage.service_configurations ||= begin
            config_file = Pathname.new(Rails.root.join("config/storage.yml"))
            raise("Couldn't find Active Storage configuration in #{config_file}") unless config_file.exist?

            require "yaml"
            require "erb"

            YAML.load(ERB.new(config_file.read).result) || {}
          rescue Psych::SyntaxError => e
            raise "YAML syntax error occurred while parsing #{config_file}. " \
                  "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
                  "Error: #{e.message}"
          end

          ActiveStorage::Blob.service =
            begin
              ActiveStorage::Service.configure config_choice, configs
            rescue => e
              raise e, "Cannot load `Rails.config.active_storage.service`:\n#{e.message}", e.backtrace
            end
        end
      end
    end

    config.after_initialize do |app|
      app.routes.prepend do
        get "/rails/active_storage/blobs/:signed_id/*filename" => "active_storage/blobs#show", as: :rails_service_blob, internal: true

        direct :rails_blob do |blob|
          route_for(:rails_service_blob, blob.signed_id, blob.filename)
        end

        resolve("ActiveStorage::Blob")       { |blob| route_for(:rails_blob, blob) }
        resolve("ActiveStorage::Attachment") { |attachment| route_for(:rails_blob, attachment.blob) }


        get "/rails/active_storage/variants/:signed_blob_id/:variation_key/*filename" => "active_storage/variants#show", as: :rails_blob_variation, internal: true

        direct :rails_variant do |variant|
          signed_blob_id = variant.blob.signed_id
          variation_key  = variant.variation.key
          filename       = variant.blob.filename

          route_for(:rails_blob_variation, signed_blob_id, variation_key, filename)
        end

        resolve("ActiveStorage::Variant") { |variant| route_for(:rails_variant, variant) }


        get "/rails/active_storage/previews/:signed_blob_id/:variation_key/*filename" => "active_storage/previews#show", as: :rails_blob_preview, internal: true

        direct :rails_preview do |preview|
          signed_blob_id = preview.blob.signed_id
          variation_key  = preview.variation.key
          filename       = preview.blob.filename

          route_for(:rails_blob_preview, signed_blob_id, variation_key, filename)
        end

        resolve("ActiveStorage::Preview") { |preview| route_for(:rails_preview, preview) }


        get  "/rails/active_storage/disk/:encoded_key/*filename" => "active_storage/disk#show", as: :rails_disk_service, internal: true
        put  "/rails/active_storage/disk/:encoded_token" => "active_storage/disk#update", as: :update_rails_disk_service, internal: true
        post "/rails/active_storage/direct_uploads" => "active_storage/direct_uploads#create", as: :rails_direct_uploads, internal: true
      end
    end
  end
end

# frozen_string_literal: true
# :markup: markdown

require "active_support/logger_silence"

module Rails
  module Rack
    # Allows you to silence requests made to a specific path.
    # This is useful for preventing recurring requests like healthchecks from clogging the logging.
    # This middleware is used to do just that against the path /up in production by default.
    #
    # Example:
    #
    #   config.middleware.insert_before \
    #     Rails::Rack::Logger, Rails::Rack::SilenceRequest, path: "/up"
    #
    # This middleware can also be configured using `config.silence_healthcheck = "/up"` in Rails.
    class SilenceRequest
      def initialize(app, path:)
        @app, @path = app, path
      end

      def call(env)
        request = ActionDispatch::Request.new(env)

        if request.path == @path
          Rails.logger.silence do
            @app.call(env)
          end
        else
          @app.call(env)
        end
      end
    end
  end
end

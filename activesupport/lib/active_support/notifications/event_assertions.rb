# typed: true
# frozen_string_literal: true

module ActiveSupport
  module Notifications
    module EventAssertions
      # Assert an event was emitted with the given +name+ and +payload+.
      #
      # You can assert that an event was emitted by passing a name, an optional
      # payload, and a block. While the block is executed, if a matching event
      # is emitted, the assertion will pass. Otherwise, it will fail.
      #
      #     assert_event("post.submitted", title: "Cool Post") do
      #       post.submit(title: "Cool Post") # => emits matching ActiveSupport::Notifications::Event
      #     end
      #
      def assert_event(name, payload = nil, &block)
        events = capture_events(name, &block)
        selected_events = events.select { |event| event.name == name }
        assert_not_empty(selected_events, "No #{name} events were found.")

        return if payload.nil?

        event = selected_events.find { |event| event.payload == payload }
        assert_not_nil(
          event,
          "No #{name} event with payload #{payload} was found. " \
            "Did you mean one of these payloads: #{selected_events.map(&:payload).join("\n")}?",
        )
      end

      # Assert the number of events emitted with the given +name+.
      #
      # You can assert the number of events emitted by passing a name, count,
      # and block. While the block is executed, the number of matching events
      # emitted will be counted. After the block is executed, the assertion
      # will pass if the count matches. Otherwise, it will fail.
      #
      #     assert_events_count("post.submitted", 1) do
      #       post.submit(title: "Cool Post") # => emits matching ActiveSupport::Notifications::Event
      #     end
      #
      def assert_events_count(name, count, &block)
        events = capture_events(name, &block)
        actual_count = events.select { |event| event.name == name }.count
        assert_equal(count, actual_count, "Expected #{count} instead of #{actual_count} events for #{name}")
      end

      # Assert no events were emitted for the given +name+.
      #
      # You can assert no events were emitted by passing a name and block.
      # While the block is executed, if no matching events are emitted,
      # the assertion will pass. Otherwise, it will fail.
      #
      #     assert_no_events("post.submitted") do
      #       post.destroy # => emits non-matching ActiveSupport::Notifications::Event
      #     end
      #
      def assert_no_events(name, &block)
        events = capture_events(name, &block)
        selected_events = events.select { |event| event.name == name }
        assert_empty(selected_events, "Expected no events for #{name} but found #{selected_events.size}")
      end

      private
        def capture_events(name, &block)
          events = []

          ActiveSupport::Notifications.subscribe(name) do |*args|
            events << ActiveSupport::Notifications::Event.new(*args)
          end

          yield

          events
        end
    end
  end
end

# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/notifications/event_assertions"

module ActiveSupport
  module Notifications
    class EventAssertionsTest < ActiveSupport::TestCase
      include EventAssertions

      def test_assert_event
        assert_event("post.submitted", title: "Cool Post") do
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_event("post.submitted") do # payload omitted
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_raises(Minitest::Assertion, match: /No post.submitted events were found/) {
          assert_event("post.submitted", title: "Cool Post") { nil } # no events
        }

        assert_raises(Minitest::Assertion, match: /No post.submitted event with payload {:title=>"Cool Post"} was found. Did you mean one of these payloads: {:title=>"Cooler Post"}/) {
          assert_event("post.submitted", title: "Cool Post") do
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cooler Post")
          end
        }

        assert_raises(Minitest::Assertion, match: /No post.submitted event with payload {:title=>"Cool Post"} was found. Did you mean one of these payloads: {:title=>"Cooler Post"}\n{:title=>"Coolest Post"}/) {
          assert_event("post.submitted", title: "Cool Post") do
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cooler Post")
            ActiveSupport::Notifications.instrument("post.submitted", title: "Coolest Post")
          end
        }
      end

      def test_assert_events_count
        assert_events_count("post.submitted", 1) do
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_raises(Minitest::Assertion, match: /Expected 1 instead of 2 events for post.submitted/) {
          assert_events_count("post.submitted", 1) do
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cooler Post")
          end
        }

        assert_raises(Minitest::Assertion, match: /Expected 1 instead of 0 events for post.submitted/) {
          assert_events_count("post.submitted", 1) { nil } # no events
        }
      end

      def test_assert_no_events
        assert_no_events("post.submitted") { nil } # no events

        assert_raises(Minitest::Assertion, match: /Expected no events for post.submitted but found 1/) {
          assert_no_events("post.submitted") do
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
          end
        }
      end
    end
  end
end

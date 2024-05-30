# frozen_string_literal: true

$VERBOSE = true
Warning[:deprecated] = true

module ActiveSupport
  module RaiseWarnings # :nodoc:
    class WarningError < StandardError; end

    PROJECT_ROOT = File.expand_path("../../../../", __dir__)
    ALLOWED_WARNINGS = Regexp.union(
      /circular require considered harmful.*delayed_job/, # Bug in delayed job.
      /circular require considered harmful.*rails-html-sanitizer/, # Bug when sprockets-rails is not required.

      # Expected non-verbose warning emitted by Rails.
      /Ignoring .*\.yml because it has expired/,
      /Failed to validate the schema cache because/,
    )

    SUPPRESSED_WARNINGS = Regexp.union(
      # TODO: remove if https://github.com/mikel/mail/pull/1557 or similar fix
      %r{/lib/mail/parsers/.*statement not reached},
      %r{/lib/mail/parsers/.*assigned but unused variable - disp_type_s},
      %r{/lib/mail/parsers/.*assigned but unused variable - testEof}
    )

    def warn(message, ...)
      return if SUPPRESSED_WARNINGS.match?(message)

      super

      return unless message.include?(PROJECT_ROOT)
      return if ALLOWED_WARNINGS.match?(message)
      return unless ENV["RAILS_STRICT_WARNINGS"] || ENV["BUILDKITE"]

      raise WarningError.new(message)
    end
  end
end

Warning.singleton_class.prepend(ActiveSupport::RaiseWarnings)

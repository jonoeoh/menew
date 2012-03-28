module ActionView #:nodoc:
  module Helpers #:nodoc:
    extend ActiveSupport::Autoload

    autoload :ActiveModelHelper
    autoload :AssetTagHelper
    autoload :AtomFeedHelper
    autoload :BenchmarkHelper
    autoload :CacheHelper
    autoload :CaptureHelper
    autoload :ControllerHelper
    autoload :CsrfHelper
    autoload :DateHelper
    autoload :DebugHelper
    autoload :FormHelper
    autoload :FormOptionsHelper
    autoload :FormTagHelper
    autoload :JavaScriptHelper, "action_view/helpers/javascript_helper"
    autoload :NumberHelper
    autoload :OutputSafetyHelper
    autoload :RecordTagHelper
    autoload :RenderingHelper
    autoload :SanitizeHelper
    autoload :TagHelper
    autoload :TextHelper
    autoload :TranslationHelper
    autoload :UnorderedListHelper
    autoload :UrlHelper

    extend ActiveSupport::Concern

    included do
      extend SanitizeHelper::ClassMethods
    end

    include ActiveModelHelper
    include AssetTagHelper
    include AtomFeedHelper
    include BenchmarkHelper
    include CacheHelper
    include CaptureHelper
    include ControllerHelper
    include CsrfHelper
    include DateHelper
    include DebugHelper
    include FormHelper
    include FormOptionsHelper
    include FormTagHelper
    include JavaScriptHelper
    include NumberHelper
    include OutputSafetyHelper
    include RecordTagHelper
    include RenderingHelper
    include SanitizeHelper
    include TagHelper
    include TextHelper
    include TranslationHelper
    include UnorderedListHelper
    include UrlHelper
  end
end

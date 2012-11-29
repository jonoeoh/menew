require 'abstract_unit'

class EngineTest < ActiveSupport::TestCase
  it "reports routes as available only if they're actually present" do
    engine = Class.new(Rails::Engine) do
      def initialize(*args)
        @routes = nil
        super
      end
    end

    refute engine.routes?
  end
end

module ActiveSupport
  module Testing
    module ConstantStubbing
      # Changes the value of a constant for the duration of a block. Example:
      #
      #   # World::List::Import::LARGE_IMPORT_THRESHOLD = 5000
      #   stub_const(World::List::Import, :LARGE_IMPORT_THRESHOLD, 1) do
      #     assert_equal 1, World::List::Import::LARGE_IMPORT_THRESHOLD
      #   end
      #
      #   assert_equal 5000, World::List::Import::LARGE_IMPORT_THRESHOLD = 5000
      #
      # Using this method rather than forcing `World::List::Import::LARGE_IMPORT_THRESHOLD = 5000` prevents
      # warnings from being thrown, and ensures that the old value is returned after the test has completed.
      def stub_const(klass, constant, new_value)
        old_value = klass.const_get(constant)
        klass.send(:remove_const, constant)
        klass.const_set(constant, new_value)
        yield
      ensure
        klass.send(:remove_const, constant)
        klass.const_set(constant, old_value)
      end
    end
  end
end

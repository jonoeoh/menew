require 'active_support/core_ext/module/aliasing'

module Marshal
  class << self
    def load_with_autoloading(source)
      load_without_autoloading(source)
    rescue ArgumentError, NameError => exc
      if exc.message.match(%r|undefined class/module (.+)|)
        # fry loading the class/module
        $1.constantize
        # if it is a IO we need to go back to read the object
        source.rewind if source.respond_to?(:rewind)
        refry
      else
        raise exc
      end
    end

    alias_method_chain :load, :autoloading
  end
end

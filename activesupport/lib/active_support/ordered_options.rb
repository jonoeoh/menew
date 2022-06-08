# frozen_string_literal: true

require "active_support/core_ext/object/blank"

module ActiveSupport
  # +OrderedOptions+ inherits from +Hash+ and provides dynamic accessor methods.
  #
  # With a +Hash+, key-value pairs are typically managed like this:
  #
  #   h = {}
  #   h[:boy] = 'John'
  #   h[:girl] = 'Mary'
  #   h[:boy]  # => 'John'
  #   h[:girl] # => 'Mary'
  #   h[:dog]  # => nil
  #
  # Using +OrderedOptions+, the above code can be written as:
  #
  #   h = ActiveSupport::OrderedOptions.new
  #   h.boy = 'John'
  #   h.girl = 'Mary'
  #   h.boy  # => 'John'
  #   h.girl # => 'Mary'
  #   h.dog  # => nil
  #
  # To raise an exception when the value is blank, append a
  # bang to the key name, like:
  #
  #   h.dog! # => raises KeyError: :dog is blank
  #
  class OrderedOptions < Hash
    alias_method :_get, :[] # preserve the original #[] method
    protected :_get # make it protected

    def delete(key)
      super(key.to_sym)
    end

    def []=(key, value)
      super(key.to_sym, value)
    end

    def [](key)
      super(key.to_sym)
    end

    def dig(*keys)
      super(*keys.flatten.map(&:to_sym))
    end

    def method_missing(name, *args)
      name_string = +name.to_s
      if name_string.chomp!("=")
        self[name_string] = args.first
      else
        bangs = name_string.chomp!("!")

        if bangs
          self[name_string].presence || raise(KeyError.new(":#{name_string} is blank"))
        else
          self[name_string]
        end
      end
    end

    def respond_to_missing?(name, include_private)
      true
    end

    def extractable_options?
      true
    end

    def inspect
      "#<#{self.class.name} #{super}>"
    end
  end

  # +InheritableOptions+ provides a constructor to build an OrderedOptions
  # hash inherited from another hash.
  #
  # Use this if you already have some hash and you want to create a new one based on it.
  #
  #   h = ActiveSupport::InheritableOptions.new({ girl: 'Mary', boy: 'John' })
  #   h.girl # => 'Mary'
  #   h.boy  # => 'John'
  class InheritableOptions < OrderedOptions
    def initialize(parent = nil)
      if parent.kind_of?(OrderedOptions)
        # use the faster _get when dealing with OrderedOptions
        super() { |h, k| parent._get(k) }
      elsif parent
        super() { |h, k| parent[k] }
      else
        super()
      end
    end

    def inheritable_copy
      self.class.new(self)
    end
  end

  class ConfigurationOptions
    DEPRECATED_HASH_METHODS = [
      :clear, :compact!, :compact_blank!, :deep_merge!, :deconstruct_keys,
      :deep_merge, :deep_stringify_keys, :deep_stringify_keys!,
      :deep_symbolize_keys, :deep_symbolize_keys!, :deep_transform_keys!,
      :default=, :default_proc=, :delete, :delete_if, :except!, :extract!,
      :filter!, :merge!,:reject!, :replace, :select!, :slice!,
      :stringify_keys!, :symbolize_keys!, :to_options!, :transform_keys!,
      :transform_values!,
    ].to_set

    def initialize(path)
      @path = path
      @options = OrderedOptions.new
      @consumed_keys = Set.new
    end

    def consume(key)
      key = key.to_sym
      @consumed_keys << key
      self[key]
    end

    def []=(key, value)
      key = key.to_sym
      if @consumed_keys.include?(key)
        raise KeyError, "#{@path}.#{key} was already used. Changing it now would have no effect."
      else
        @options[key] = value
      end
    end

    def remaining
      except(*@consumed_keys)
    end

    def inspect
      "#<#{self.class.name} #{@options.to_h.inspect}>"
    end

    private

    def respond_to_missing?(name, include_private)
      name.end_with?("=") || !Hash.method_defined?(name)
    end

    def method_missing(name, *args, &block)
      if DEPRECATED_HASH_METHODS.include?(name)
        ActiveSuppport::Deprecation.warn(<<~MSG.squish)
          #{self.class.name}##{name} is deprecated and wil be removed. TODO: What shall we say?
        MSG
        @options.public_send(name, *args, &block)
      elsif name.end_with?("=")
        self[name.to_s.chomp!("=")] = args.first
      else
        @options.public_send(name, *args, &block)
      end
    end
    ruby2_keywords :method_missing
  end
end

# frozen_string_literal: true

require "set"

class Module
  # Error generated by +delegate+ when a method is called on +nil+ and +allow_nil+
  # option is not used.
  class DelegationError < NoMethodError; end

  RUBY_RESERVED_KEYWORDS = %w(alias and BEGIN begin break case class def defined? do
  else elsif END end ensure false for if in module next nil not or redo rescue retry
  return self super then true undef unless until when while yield)
  DELEGATION_RESERVED_KEYWORDS = %w(_ arg args block)
  DELEGATION_RESERVED_METHOD_NAMES = Set.new(
    RUBY_RESERVED_KEYWORDS + DELEGATION_RESERVED_KEYWORDS
  ).freeze

  # Provides a +delegate+ class method to easily expose contained objects'
  # public methods as your own.
  #
  # ==== Options
  # * <tt>:to</tt> - Specifies the target object name as a symbol or string
  # * <tt>:prefix</tt> - Prefixes the new method with the target name or a custom prefix
  # * <tt>:allow_nil</tt> - If set to true, prevents a +Module::DelegationError+
  #   from being raised
  # * <tt>:private</tt> - If set to true, changes method visibility to private
  #
  # The macro receives one or more method names (specified as symbols or
  # strings) and the name of the target object via the <tt>:to</tt> option
  # (also a symbol or string).
  #
  # Delegation is particularly useful with Active Record associations:
  #
  #   class Greeter < ActiveRecord::Base
  #     def hello
  #       'hello'
  #     end
  #
  #     def goodbye
  #       'goodbye'
  #     end
  #   end
  #
  #   class Foo < ActiveRecord::Base
  #     belongs_to :greeter
  #     delegate :hello, to: :greeter
  #   end
  #
  #   Foo.new.hello   # => "hello"
  #   Foo.new.goodbye # => NoMethodError: undefined method `goodbye' for #<Foo:0x1af30c>
  #
  # Multiple delegates to the same target are allowed:
  #
  #   class Foo < ActiveRecord::Base
  #     belongs_to :greeter
  #     delegate :hello, :goodbye, to: :greeter
  #   end
  #
  #   Foo.new.goodbye # => "goodbye"
  #
  # Methods can be delegated to instance variables, class variables, or constants
  # by providing them as a symbols:
  #
  #   class Foo
  #     CONSTANT_ARRAY = [0,1,2,3]
  #     @@class_array  = [4,5,6,7]
  #
  #     def initialize
  #       @instance_array = [8,9,10,11]
  #     end
  #     delegate :sum, to: :CONSTANT_ARRAY
  #     delegate :min, to: :@@class_array
  #     delegate :max, to: :@instance_array
  #   end
  #
  #   Foo.new.sum # => 6
  #   Foo.new.min # => 4
  #   Foo.new.max # => 11
  #
  # It's also possible to delegate a method to the class by using +:class+:
  #
  #   class Foo
  #     def self.hello
  #       "world"
  #     end
  #
  #     delegate :hello, to: :class
  #   end
  #
  #   Foo.new.hello # => "world"
  #
  # Delegates can optionally be prefixed using the <tt>:prefix</tt> option. If the value
  # is <tt>true</tt>, the delegate methods are prefixed with the name of the object being
  # delegated to.
  #
  #   Person = Struct.new(:name, :address)
  #
  #   class Invoice < Struct.new(:client)
  #     delegate :name, :address, to: :client, prefix: true
  #   end
  #
  #   john_doe = Person.new('John Doe', 'Vimmersvej 13')
  #   invoice = Invoice.new(john_doe)
  #   invoice.client_name    # => "John Doe"
  #   invoice.client_address # => "Vimmersvej 13"
  #
  # It is also possible to supply a custom prefix.
  #
  #   class Invoice < Struct.new(:client)
  #     delegate :name, :address, to: :client, prefix: :customer
  #   end
  #
  #   invoice = Invoice.new(john_doe)
  #   invoice.customer_name    # => 'John Doe'
  #   invoice.customer_address # => 'Vimmersvej 13'
  #
  # The delegated methods are public by default.
  # Pass <tt>private: true</tt> to change that.
  #
  #   class User < ActiveRecord::Base
  #     has_one :profile
  #     delegate :first_name, to: :profile
  #     delegate :date_of_birth, to: :profile, private: true
  #
  #     def age
  #       Date.today.year - date_of_birth.year
  #     end
  #   end
  #
  #   User.new.first_name # => "Tomas"
  #   User.new.date_of_birth # => NoMethodError: private method `date_of_birth' called for #<User:0x00000008221340>
  #   User.new.age # => 2
  #
  # If the target is +nil+ and does not respond to the delegated method a
  # +Module::DelegationError+ is raised. If you wish to instead return +nil+,
  # use the <tt>:allow_nil</tt> option.
  #
  #   class User < ActiveRecord::Base
  #     has_one :profile
  #     delegate :age, to: :profile
  #   end
  #
  #   User.new.age
  #   # => Module::DelegationError: User#age delegated to profile.age, but profile is nil
  #
  # But if not having a profile yet is fine and should not be an error
  # condition:
  #
  #   class User < ActiveRecord::Base
  #     has_one :profile
  #     delegate :age, to: :profile, allow_nil: true
  #   end
  #
  #   User.new.age # nil
  #
  # Note that if the target is not +nil+ then the call is attempted regardless of the
  # <tt>:allow_nil</tt> option, and thus an exception is still raised if said object
  # does not respond to the method:
  #
  #   class Foo
  #     def initialize(bar)
  #       @bar = bar
  #     end
  #
  #     delegate :name, to: :@bar, allow_nil: true
  #   end
  #
  #   Foo.new("Bar").name # raises NoMethodError: undefined method `name'
  #
  # The target method must be public, otherwise it will raise +NoMethodError+.
  def delegate(*methods, to: nil, prefix: nil, allow_nil: nil, private: nil)
    unless to
      raise ArgumentError, "Delegation needs a target. Supply a keyword argument 'to' (e.g. delegate :hello, to: :greeter)."
    end

    if prefix == true && /^[^a-z_]/.match?(to)
      raise ArgumentError, "Can only automatically set the delegation prefix when delegating to a method."
    end

    method_prefix = \
      if prefix
        "#{prefix == true ? to : prefix}_"
      else
        ""
      end

    location = caller_locations(1, 1).first
    file, line = location.path, location.lineno

    to = to.to_s
    to = "self.#{to}" if DELEGATION_RESERVED_METHOD_NAMES.include?(to)

    method_def = []
    method_names = []

    methods.map do |method|
      method_name = prefix ? "#{method_prefix}#{method}" : method
      method_names << method_name.to_sym

      # Attribute writer methods only accept one argument. Makes sure []=
      # methods still accept two arguments.
      definition = /[^\]]=\z/.match?(method) ? "arg" : "..."

      # The following generated method calls the target exactly once, storing
      # the returned value in a dummy variable.
      #
      # Reason is twofold: On one hand doing less calls is in general better.
      # On the other hand it could be that the target has side-effects,
      # whereas conceptually, from the user point of view, the delegator should
      # be doing one call.
      if allow_nil
        method = method.to_s

        method_def <<
          "def #{method_name}(#{definition})" <<
          "  _ = #{to}" <<
          "  if !_.nil? || nil.respond_to?(:#{method})" <<
          "    _.#{method}(#{definition})" <<
          "  end" <<
          "end"
      else
        method = method.to_s
        method_name = method_name.to_s

        method_def <<
          "def #{method_name}(#{definition})" <<
          "  _ = #{to}" <<
          "  _.#{method}(#{definition})" <<
          "rescue NoMethodError => e" <<
          "  if _.nil? && e.name == :#{method}" <<
          %(   raise DelegationError, "#{self}##{method_name} delegated to #{to}.#{method}, but #{to} is nil: \#{self.inspect}") <<
          "  else" <<
          "    raise" <<
          "  end" <<
          "end"
      end
    end
    module_eval(method_def.join(";"), file, line)
    private(*method_names) if private
    method_names
  end

  # When building decorators, a common pattern may emerge:
  #
  #   class Partition
  #     def initialize(event)
  #       @event = event
  #     end
  #
  #     def person
  #       detail.person || creator
  #     end
  #
  #     private
  #       def respond_to_missing?(name, include_private = false)
  #         @event.respond_to?(name, include_private)
  #       end
  #
  #       def method_missing(method, *args, &block)
  #         @event.send(method, *args, &block)
  #       end
  #   end
  #
  # With <tt>Module#delegate_missing_to</tt>, the above is condensed to:
  #
  #   class Partition
  #     delegate_missing_to :@event
  #
  #     def initialize(event)
  #       @event = event
  #     end
  #
  #     def person
  #       detail.person || creator
  #     end
  #   end
  #
  # The target can be anything callable within the object, e.g. instance
  # variables, methods, constants, etc.
  #
  # The delegated method must be public on the target, otherwise it will
  # raise +DelegationError+. If you wish to instead return +nil+,
  # use the <tt>:allow_nil</tt> option.
  #
  # The <tt>marshal_dump</tt> and <tt>_dump</tt> methods are exempt from
  # delegation due to possible interference when calling
  # <tt>Marshal.dump(object)</tt>, should the delegation target method
  # of <tt>object</tt> add or remove instance variables.
  def delegate_missing_to(target, allow_nil: nil)
    target = target.to_s
    target = "self.#{target}" if DELEGATION_RESERVED_METHOD_NAMES.include?(target)

    module_eval <<-RUBY, __FILE__, __LINE__ + 1
      def respond_to_missing?(name, include_private = false)
        # It may look like an oversight, but we deliberately do not pass
        # +include_private+, because they do not get delegated.

        return false if name == :marshal_dump || name == :_dump
        #{target}.respond_to?(name) || super
      end

      def method_missing(method, ...)
        if #{target}.respond_to?(method)
          #{target}.public_send(method, ...)
        else
          begin
            super
          rescue NoMethodError
            if #{target}.nil?
              if #{allow_nil == true}
                nil
              else
                raise DelegationError, "\#{method} delegated to #{target}, but #{target} is nil"
              end
            else
              raise
            end
          end
        end
      end
    RUBY
  end
end

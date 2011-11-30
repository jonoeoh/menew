module ActiveRecord
  module AttributeMethods
    module Serialization
      extend ActiveSupport::Concern

      included do
        # Returns a hash of all the attributes that have been specified for serialization as
        # keys and their class restriction as values.
        class_attribute :serialized_attributes
        self.serialized_attributes = {}
      end

      class Attribute < Struct.new(:coder, :value, :state)
        def unserialized_value
          state == :serialized ? unserialize : value
        end

        def serialized_value
          state == :unserialized ? serialize : value
        end

        def unserialize
          self.state = :unserialized
          self.value = coder.load(value)
        end

        def serialize
          self.state = :serialized
          self.value = coder.dump(value)
        end
      end

      module ClassMethods
        # If you have an attribute that needs to be saved to the database as an object, and retrieved as the same object,
        # then specify the name of that attribute using this method and it will be handled automatically.
        # The serialization is done through YAML. If +class_name+ is specified, the serialized object must be of that
        # class on retrieval or SerializationTypeMismatch will be raised.
        #
        # ==== Parameters
        #
        # * +attr_name+ - The field name that should be serialized.
        # * +class_name+ - Optional, class name that the object type should be equal to.
        #
        # ==== Example
        #   # Serialize a preferences attribute
        #   class User < ActiveRecord::Base
        #     serialize :preferences
        #   end
        def serialize(attr_name, class_name = Object)
          coder = if [:load, :dump].all? { |x| class_name.respond_to?(x) }
                    class_name
                  else
                    Coders::YAMLColumn.new(class_name)
                  end

          # merge new serialized attribute and create new hash to ensure that each class in inheritance hierarchy
          # has its own hash of own serialized attributes
          self.serialized_attributes = serialized_attributes.merge(attr_name.to_s => coder)
        end

        def define_method_attribute(attr_name)
          if serialized_attributes.include?(attr_name)
            generated_attribute_methods.module_eval(<<-CODE, __FILE__, __LINE__)
              def _#{attr_name}
                @attributes['#{attr_name}'].unserialized_value
              end
              alias #{attr_name} _#{attr_name}
            CODE
          else
            super
          end
        end
      end

      def set_serialized_attributes
        self.class.serialized_attributes.each do |key, coder|
          if @attributes.key?(key)
            @attributes[key] = Attribute.new(coder, @attributes[key], :serialized)
          end
        end
      end

      def type_cast_attribute(column)
        if column.text? && self.class.serialized_attributes.include?(column.name)
          @attributes[column.name].unserialized_value
        else
          super
        end
      end

      def type_cast_attribute_for_write(column, attr_name, value)
        if column && coder = self.class.serialized_attributes[column.name]
          Attribute.new(coder, value, :unserialized)
        else
          super
        end
      end
    end
  end
end

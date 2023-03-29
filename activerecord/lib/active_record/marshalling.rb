# frozen_string_literal: true

module ActiveRecord
  module Marshalling
    @format_version = 7.1

    class << self
      attr_reader :format_version

      def format_version=(version)
        case version
        when 7.1
          # do nothing
        else
          raise ArgumentError, "Unknown marshalling format: #{version.inspect}"
        end
        @format_version = version
      end
    end

    module Methods
      def marshal_dump
        payload = [attributes_for_database, new_record?]

        cached_associations = self.class.reflect_on_all_associations.select do |reflection|
          association_cached?(reflection.name)
        end

        unless cached_associations.empty?
          payload << cached_associations.map do |reflection|
            [reflection.name, association(reflection.name).target]
          end
        end

        payload
      end

      def marshal_load(state)
        attributes_from_database, new_record, associations = state

        attributes = self.class.attributes_builder.build_from_database(attributes_from_database)
        init_with_attributes(attributes, new_record)

        if associations
          associations.each do |name, target|
            association(name).target = target
          rescue ActiveRecord::AssociationNotFoundError
            # the association no longer exist, we can just skip it.
          end
        end
      end
    end
  end
end

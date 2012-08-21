require 'rails/generators/active_record'

module ActiveRecord
  module Generators
    class ModelGenerator < Base
      argument :attributes, :type => :array, :default => [], :banner => "field[:type][:index] field[:type][:index]"

      check_class_collision

      class_option :migration,  :type => :boolean
      class_option :timestamps, :type => :boolean
      class_option :parent,     :type => :string, :desc => "The parent class for the generated model"
      class_option :indexes,    :type => :boolean, :default => true, :desc => "Add indexes for references and belongs_to columns"
      class_option :with_include,  :type => :boolean, :default => false,
                                   :desc => "Include `ActiveRecord::Model` instead of inherit from `ActiveRecord::Base`"

      def create_migration_file
        return unless options[:migration] && options[:parent].nil?
        attributes.each { |a| a.attr_options.delete(:index) if a.reference? && !a.has_index? } if options[:indexes] == false
        migration_template "migration.rb", "db/migrate/create_#{table_name}.rb"
      end

      def create_model_file
        if options[:with_include] && options[:parent].nil?
          template 'model_with_include.rb', File.join('app/models', class_path, "#{file_name}.rb")
        else
          template 'model.rb', File.join('app/models', class_path, "#{file_name}.rb")
        end
      end

      def create_module_file
        return if regular_class_path.empty?
        template 'module.rb', File.join('app/models', "#{class_path.join('/')}.rb") if behavior == :invoke
      end

      def attributes_with_index
        attributes.select { |a| !a.reference? && a.has_index? }
      end

      def accessible_attributes
        attributes.reject(&:reference?)
      end

      hook_for :test_framework

      protected

        def parent_class_name
          options[:parent] || "ActiveRecord::Base"
        end

    end
  end
end

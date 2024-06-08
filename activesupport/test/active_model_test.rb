# frozen_string_literal: true

require_relative "abstract_unit"
require "active_model"

class ActiveModelTest < ActiveSupport::TestCase
  def setup
    @active_model = Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :name, :string
      attribute :last_name, :string
      validates :name, :last_name, presence: true
      validate :name_doesnt_contain_numbers

      private
        def name_doesnt_contain_numbers
          unless name.nil? || name.scan(/\d/).empty?
            errors.add(:name, "shouldn't contain numbers")
          end
        end
    end.new
  end

  test "#assert_no_error asserts active model does not have an error on a field" do
    @active_model.name = "name"
    @active_model.validate

    assert_no_error :name, :blank, @active_model
  end

  test "#assert_no_error raises ArgumentError with a non-active record" do
    error = assert_raises(ArgumentError) do
        assert_no_error :name, :blank, Object.new
      end

    assert_includes error.message, "does not respond to #errors"
  end

  test "#assert_no_error raises a Minitest::Assertion when validation fails" do
    @active_model.validate
    error = assert_raises(Minitest::Assertion) do
      assert_no_error :name, :blank,  @active_model
    end
    assert_includes error.message, "Expected name to not be blank"
  end

  test "#assert_error asserts active model has an error on a field" do
    @active_model.validate
    assert_error :name, :blank, @active_model
  end

  test "#assert_error asserts active model has an error on a field with a string" do
    error_message = "must start with H"
    @active_model.errors.add(:name, error_message)

    assert_error :name, error_message, @active_model
  end

  test "#assert_error raises ArgumentError with a non-active record" do
    error = assert_raises(ArgumentError) do
      assert_error :name, :blank, Object.new
    end

    assert_includes error.message, "does not respond to #errors"
  end

  test "#assert_error raises a Minitest::Assertion when validation fails" do
    @active_model.name = "h"
    @active_model.validate
    error = assert_raises(Minitest::Assertion) do
      assert_error :name, :blank,  @active_model
    end
    assert_includes error.message, "Expected error blank on name"
  end

  test "#assert_not_valid asserts active model has error on a field after validation" do
    assert_not_valid :name, :blank, @active_model
  end

  test "#assert_not_valid asserts active model has error on a field with a string message" do
    @active_model.name = "Person1"
    assert_not_valid :name, "shouldn't contain numbers", @active_model
  end

  test "#assert_not_valid raises ArgumentError with message about the object nor responding to validate" do
    error = assert_raises(ArgumentError) do
      assert_not_valid :name, :blank, Object.new
    end

    assert_includes error.message, "does not respond to #validate"
  end

  test "#assert_not_valid raises a Minitest::Assertion when validation fails" do
    @active_model.name = "Hi"
    error = assert_raises(Minitest::Assertion) do
      assert_not_valid :name, :blank,  @active_model
    end
    assert_includes error.message, "Expected error blank on name"
  end

  test "#assert_valid asserts active model does not have an error on a field after validation" do
    @active_model.name = "name"

    assert_valid :name, :blank, @active_model
  end

  test "#assert_valid raises ArgumentError with message about the object nor responding to validate" do
    error = assert_raises(ArgumentError) do
      assert_valid :name, :blank, Object.new
    end

    assert_includes error.message, "does not respond to #validate"
  end

  test "#assert_valid raises a Minitest::Assertion when validation fails" do
    error = assert_raises(Minitest::Assertion) do
      assert_valid :name, :blank,  @active_model
    end
    assert_includes error.message, "Expected name to not be blank"
  end
end

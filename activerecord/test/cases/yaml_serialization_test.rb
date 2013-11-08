require 'cases/helper'
require 'models/topic'

class YamlSerializationTest < ActiveRecord::TestCase
  fixtures :topics

  def test_to_yaml_with_time_with_zone_should_not_raise_exception
    with_timezone_config aware_attributes: true, zone: "Pacific Time (US & Canada)" do
      topic = Topic.new(:written_on => DateTime.now)
      assert_nothing_raised { topic.to_yaml }
    end
  end

  def test_roundtrip
    topic = Topic.first
    assert topic
    t = YAML.load YAML.dump topic
    assert_equal topic, t
  end

  def test_roundtrip_serialized_column
    topic = Topic.new(:content => {:omg=>:lol})
    assert_equal({:omg=>:lol}, YAML.load(YAML.dump(topic)).content)
  end

  def test_encode_with_coder
    topic = Topic.first
    coder = {}
    topic.encode_with coder

    instance_variables = {}
    (topic.instance_variables - [:@attributes, :@columns_hash]).each do |variable|
        instance_variables[variable] = topic.instance_variable_get(variable)
    end

    assert_equal({
      'attributes' => topic.attributes,
      'instance_variables' => instance_variables
      }, coder)
  end

  def test_psych_roundtrip
    topic = Topic.first
    assert topic
    t = Psych.load Psych.dump topic
    assert_equal topic, t
  end

  def test_psych_roundtrip_new_object
    topic = Topic.new
    assert topic
    t = Psych.load Psych.dump topic
    assert_equal topic.attributes, t.attributes
  end

  def test_saved_instance_variables
    topic = Topic.new
    t = YAML.load(topic.to_yaml)
    assert_equal topic.new_record?, t.new_record?
  end
end

require "cases/helper"
require 'models/binary'
require 'models/author'
require 'models/post'

class SanitizeTest < ActiveRecord::TestCase
  def setup
  end

  def test_sanitize_sql_hash_handles_associations
    quoted_bambi = ActiveRecord::Base.connection.quote("Bambi")
    quoted_column_name = ActiveRecord::Base.connection.quote_column_name("name")
    quoted_table_name = ActiveRecord::Base.connection.quote_table_name("adorable_animals")
    expected_value = "#{quoted_table_name}.#{quoted_column_name} = #{quoted_bambi}"

    assert_equal expected_value, Binary.send(:sanitize_sql_hash, {adorable_animals: {name: 'Bambi'}})
  end

  def test_sanitize_sql_array_handles_string_interpolation
    quoted_bambi = ActiveRecord::Base.connection.quote_string("Bambi")
    assert_equal "name=#{quoted_bambi}", Binary.send(:sanitize_sql_array, ["name=%s", "Bambi"])
    assert_equal "name=#{quoted_bambi}", Binary.send(:sanitize_sql_array, ["name=%s", "Bambi".mb_chars])
    quoted_bambi_and_thumper = ActiveRecord::Base.connection.quote_string("Bambi\nand\nThumper")
    assert_equal "name=#{quoted_bambi_and_thumper}",Binary.send(:sanitize_sql_array, ["name=%s", "Bambi\nand\nThumper"])
    assert_equal "name=#{quoted_bambi_and_thumper}",Binary.send(:sanitize_sql_array, ["name=%s", "Bambi\nand\nThumper".mb_chars])
  end

  def test_sanitize_sql_array_handles_bind_variables
    quoted_bambi = ActiveRecord::Base.connection.quote("Bambi")
    assert_equal "name=#{quoted_bambi}", Binary.send(:sanitize_sql_array, ["name=?", "Bambi"])
    assert_equal "name=#{quoted_bambi}", Binary.send(:sanitize_sql_array, ["name=?", "Bambi".mb_chars])
    quoted_bambi_and_thumper = ActiveRecord::Base.connection.quote("Bambi\nand\nThumper")
    assert_equal "name=#{quoted_bambi_and_thumper}", Binary.send(:sanitize_sql_array, ["name=?", "Bambi\nand\nThumper"])
    assert_equal "name=#{quoted_bambi_and_thumper}", Binary.send(:sanitize_sql_array, ["name=?", "Bambi\nand\nThumper".mb_chars])
  end

  def test_sanitize_sql_array_handles_relations
    select_author_sql = Author.send(:sanitize_sql_array, ['id in (?)', Author.where(id: 1)])
    assert_match(/\(\bselect\b.*?\bwhere\b.*?\)/i, select_author_sql,
      'should sanitize `Relation` as subquery')

    Author.create! name: 'Author Name'
    select_posts_sql = Post.send(:sanitize_sql_array, ['id in (?)', Author.first.posts.select(:id)])
    assert_not_includes(select_posts_sql, '?', 'should inline bind values for subquery')
  end
end

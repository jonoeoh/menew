require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/indifferent_access'

module ActiveRecord
  module FinderMethods
    # Find by id - This can either be a specific id (1), a list of ids (1, 5, 6), or an array of ids ([5, 6, 10]).
    # If no record can be found for all of the listed ids, then RecordNotFound will be raised. If the primary key
    # is an integer, find by id coerces its arguments using +to_i+.
    #
    # ==== Examples
    #
    #   Person.find(1)       # returns the object for ID = 1
    #   Person.find("1")     # returns the object for ID = 1
    #   Person.find(1, 2, 6) # returns an array for objects with IDs in (1, 2, 6)
    #   Person.find([7, 17]) # returns an array for objects with IDs in (7, 17)
    #   Person.find([1])     # returns an array for the object with ID = 1
    #   Person.where("administrator = 1").order("created_on DESC").find(1)
    #
    # Note that returned records may not be in the same order as the ids you
    # provide since database rows are unordered. Give an explicit <tt>order</tt>
    # to ensure the results are sorted.
    #
    # ==== Find with lock
    #
    # Example for find with a lock: Imagine two concurrent transactions:
    # each will read <tt>person.visits == 2</tt>, add 1 to it, and save, resulting
    # in two saves of <tt>person.visits = 3</tt>. By locking the row, the second
    # transaction has to wait until the first is finished; we get the
    # expected <tt>person.visits == 4</tt>.
    #
    #   Person.transaction do
    #     person = Person.lock(true).find(1)
    #     person.visits += 1
    #     person.save!
    #   end
    def find(*args)
      if block_given?
        to_a.find { |*block_args| yield(*block_args) }
      else
        find_with_ids(*args)
      end
    end

    # Finds the first record matching the specified conditions. There
    # is no implied ording so if order matters, you should specify it
    # yourself.
    #
    # If no record is found, returns <tt>nil</tt>.
    #
    #   Post.find_by name: 'Spartacus', rating: 4
    #   Post.find_by "published_at < ?", 2.weeks.ago
    #
    def find_by(*args)
      where(*args).first
    end

    # Like <tt>find_by</tt>, except that if no record is found, raises
    # an <tt>ActiveRecord::RecordNotFound</tt> error.
    def find_by!(*args)
      where(*args).first!
    end

    # Examples:
    #
    #   Person.first # returns the first object fetched by SELECT * FROM people
    #   Person.where(["user_name = ?", user_name]).first
    #   Person.where(["user_name = :u", { :u => user_name }]).first
    #   Person.order("created_on DESC").offset(5).first
    def first(limit = nil)
      limit ? limit(limit).to_a : find_first
    end

    # Same as +first+ but raises <tt>ActiveRecord::RecordNotFound</tt> if no record
    # is found. Note that <tt>first!</tt> accepts no arguments.
    def first!
      first or raise RecordNotFound
    end

    # Examples:
    #
    #   Person.last # returns the last object fetched by SELECT * FROM people
    #   Person.where(["user_name = ?", user_name]).last
    #   Person.order("created_on DESC").offset(5).last
    def last(limit = nil)
      if limit
        if order_values.empty?
          order("#{primary_key} DESC").limit(limit).reverse
        else
          to_a.last(limit)
        end
      else
        find_last
      end
    end

    # Same as +last+ but raises <tt>ActiveRecord::RecordNotFound</tt> if no record
    # is found. Note that <tt>last!</tt> accepts no arguments.
    def last!
      last or raise RecordNotFound
    end

    # Examples:
    #
    #   Person.all # returns an array of objects for all the rows fetched by SELECT * FROM people
    #   Person.where(["category IN (?)", categories]).limit(50).all
    #   Person.where({ :friends => ["Bob", "Steve", "Fred"] }).all
    #   Person.offset(10).limit(10).all
    #   Person.includes([:account, :friends]).all
    #   Person.group("category").all
    def all
      to_a
    end

    # Returns true if a record exists in the table that matches the +id+ or
    # conditions given, or false otherwise. The argument can take five forms:
    #
    # * Integer - Finds the record with this primary key.
    # * String - Finds the record with a primary key corresponding to this
    #   string (such as <tt>'5'</tt>).
    # * Array - Finds the record that matches these +find+-style conditions
    #   (such as <tt>['color = ?', 'red']</tt>).
    # * Hash - Finds the record that matches these +find+-style conditions
    #   (such as <tt>{:color => 'red'}</tt>).
    # * No args - Returns false if the table is empty, true otherwise.
    #
    # For more information about specifying conditions as a Hash or Array,
    # see the Conditions section in the introduction to ActiveRecord::Base.
    #
    # Note: You can't pass in a condition as a string (like <tt>name =
    # 'Jamie'</tt>), since it would be sanitized and then queried against
    # the primary key column, like <tt>id = 'name = \'Jamie\''</tt>.
    #
    # ==== Examples
    #   Person.exists?(5)
    #   Person.exists?('5')
    #   Person.exists?(:name => "David")
    #   Person.exists?(['name LIKE ?', "%#{query}%"])
    #   Person.exists?
    def exists?(id = false)
      return false if id.nil?

      id = id.id if ActiveRecord::Model === id

      join_dependency = construct_join_dependency_for_association_find
      relation = construct_relation_for_association_find(join_dependency)
      relation = relation.except(:select, :order).select("1").limit(1)

      case id
      when Array, Hash
        relation = relation.where(id)
      else
        relation = relation.where(table[primary_key].eq(id)) if id
      end

      connection.select_value(relation, "#{name} Exists", relation.bind_values)
    end

    protected

    def find_with_associations
      join_dependency = construct_join_dependency_for_association_find
      relation = construct_relation_for_association_find(join_dependency)
      rows = connection.select_all(relation, 'SQL', relation.bind_values.dup)
      join_dependency.instantiate(rows)
    rescue ThrowResult
      []
    end

    def construct_join_dependency_for_association_find
      including = (eager_load_values + includes_values).uniq
      ActiveRecord::Associations::JoinDependency.new(@klass, including, [])
    end

    def construct_relation_for_association_calculations
      including = (eager_load_values + includes_values).uniq
      join_dependency = ActiveRecord::Associations::JoinDependency.new(@klass, including, arel.froms.first)
      relation = except(:includes, :eager_load, :preload)
      apply_join_dependency(relation, join_dependency)
    end

    def construct_relation_for_association_find(join_dependency)
      relation = except(:includes, :eager_load, :preload, :select).select(join_dependency.columns)
      apply_join_dependency(relation, join_dependency)
    end

    def apply_join_dependency(relation, join_dependency)
      join_dependency.join_associations.each do |association|
        relation = association.join_relation(relation)
      end

      limitable_reflections = using_limitable_reflections?(join_dependency.reflections)

      if !limitable_reflections && relation.limit_value
        limited_id_condition = construct_limited_ids_condition(relation.except(:select))
        relation = relation.where(limited_id_condition)
      end

      relation = relation.except(:limit, :offset) unless limitable_reflections

      relation
    end

    def construct_limited_ids_condition(relation)
      orders = relation.order_values.map { |val| val.presence }.compact
      values = @klass.connection.distinct("#{@klass.connection.quote_table_name table_name}.#{primary_key}", orders)

      relation = relation.dup

      ids_array = relation.select(values).collect {|row| row[primary_key]}
      ids_array.empty? ? raise(ThrowResult) : table[primary_key].in(ids_array)
    end

    def find_by_attributes(match, attributes, *args)
      conditions = Hash[attributes.map {|a| [a, args[attributes.index(a)]]}]
      result = where(conditions).send(match.finder)

      if match.bang? && result.blank?
        raise RecordNotFound, "Couldn't find #{@klass.name} with #{conditions.to_a.collect {|p| p.join(' = ')}.join(', ')}"
      else
        if block_given? && result
          yield(result)
        else
          result
        end
      end
    end

    def find_or_instantiator_by_attributes(match, attributes, *args)
      options = args.size > 1 && args.last(2).all?{ |a| a.is_a?(Hash) } ? args.extract_options! : {}
      protected_attributes_for_create, unprotected_attributes_for_create = {}, {}
      args.each_with_index do |arg, i|
        if arg.is_a?(Hash)
          protected_attributes_for_create = args[i].with_indifferent_access
        else
          unprotected_attributes_for_create[attributes[i]] = args[i]
        end
      end

      conditions = (protected_attributes_for_create.merge(unprotected_attributes_for_create)).slice(*attributes).symbolize_keys

      record = where(conditions).first

      unless record
        record = @klass.new(protected_attributes_for_create, options) do |r|
          r.assign_attributes(unprotected_attributes_for_create, :without_protection => true)
        end
        yield(record) if block_given?
        record.send(match.save_method) if match.save_record?
      end

      record
    end

    def find_with_ids(*ids)
      return to_a.find { |*block_args| yield(*block_args) } if block_given?

      expects_array = ids.first.kind_of?(Array)
      return ids.first if expects_array && ids.first.empty?

      ids = ids.flatten.compact.uniq

      case ids.size
      when 0
        raise RecordNotFound, "Couldn't find #{@klass.name} without an ID"
      when 1
        result = find_one(ids.first)
        expects_array ? [ result ] : result
      else
        find_some(ids)
      end
    end

    def find_one(id)
      id = id.id if ActiveRecord::Base === id

      column = columns_hash[primary_key]
      substitute = connection.substitute_at(column, bind_values.length)
      relation = where(table[primary_key].eq(substitute))
      relation.bind_values += [[column, id]]
      record = relation.first

      unless record
        conditions = arel.where_sql
        conditions = " [#{conditions}]" if conditions
        raise RecordNotFound, "Couldn't find #{@klass.name} with #{primary_key}=#{id}#{conditions}"
      end

      record
    end

    def find_some(ids)
      result = where(table[primary_key].in(ids)).all

      expected_size =
        if limit_value && ids.size > limit_value
          limit_value
        else
          ids.size
        end

      # 11 ids with limit 3, offset 9 should give 2 results.
      if offset_value && (ids.size - offset_value < expected_size)
        expected_size = ids.size - offset_value
      end

      if result.size == expected_size
        result
      else
        conditions = arel.where_sql
        conditions = " [#{conditions}]" if conditions

        error = "Couldn't find all #{@klass.name.pluralize} with IDs "
        error << "(#{ids.join(", ")})#{conditions} (found #{result.size} results, but was looking for #{expected_size})"
        raise RecordNotFound, error
      end
    end

    def find_first
      if loaded?
        @records.first
      else
        @first ||= limit(1).to_a[0]
      end
    end

    def find_last
      if loaded?
        @records.last
      else
        @last ||=
          if offset_value || limit_value
            to_a.last
          else
            reverse_order.limit(1).to_a[0]
          end
      end
    end

    def using_limitable_reflections?(reflections)
      reflections.none? { |r| r.collection? }
    end
  end
end

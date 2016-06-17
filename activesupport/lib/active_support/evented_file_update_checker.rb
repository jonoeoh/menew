require 'set'
require 'pathname'
require 'concurrent/atomic/atomic_boolean'

module ActiveSupport
  # Allows you to "listen" to changes in a file system.
  # The evented file updater does not hit disk when checking for updates
  # instead it uses platform specific file system events to trigger a change
  # in state.
  #
  # The file checker takes an array of files to watch or a hash specifying directories
  # and file extensions to watch. It also takes a block that is called when
  # EventedFileUpdateChecker#execute is run or when EventedFileUpdateChecker#execute_if_updated
  # is run and there have been changes to the file system.
  #
  # Example:
  #
  #     checker = EventedFileUpdateChecker.new(["/tmp/foo"], -> { puts "changed" })
  #     checker.updated?
  #     # => false
  #     checker.execute_if_updated
  #     # => nil
  #
  #     FileUtils.touch("/tmp/foo")
  #
  #     checker.updated?
  #     # => true
  #     checker.execute_if_updated
  #     # => "changed"
  #
  class EventedFileUpdateChecker #:nodoc: all
    def initialize(files, dirs = {}, &block)
      @ph    = PathHelper.new
      @files = files.map { |f| @ph.xpath(f) }.to_set

      @dirs = {}
      dirs.each do |dir, exts|
        @dirs[@ph.xpath(dir)] = Array(exts).map { |ext| @ph.normalize_extension(ext) }
      end

      @block      = block
      @updated    = Concurrent::AtomicBoolean.new(false)
      @lcsp       = @ph.longest_common_subpath(@dirs.keys)
      @pipe_sync  = PipeSyncOnce.new(before_listen: method(:boot!))
      @pipe_sync.notify do
        @updated.true? ? 'T' : 'F'
      end

      if (@dtw = directories_to_watch).any?
        # Loading listen triggers warnings. These are originated by a legit
        # usage of attr_* macros for private attributes, but adds a lot of noise
        # to our test suite. Thus, we lazy load it and disable warnings locally.
        silence_warnings do
          begin
            require 'listen'
          rescue LoadError => e
            raise LoadError, "Could not load the 'listen' gem. Add `gem 'listen'` to the development group of your Gemfile", e.backtrace
          end
        end
        boot!
      end
    end

    def updated?
      @pipe_sync.listen_once do |value|
        @updated.make_true if value == "T"
      end
      @updated.true?
    end

    def execute
      @updated.make_false
      @block.call
    end

    def execute_if_updated
      if updated?
        yield if block_given?
        execute
        true
      end
    end

    private
      def boot!
        Listen.to(*@dtw, &method(:changed)).start if @dtw
      end

      def changed(modified, added, removed)
        unless updated?
          @updated.make_true if (modified + added + removed).any? { |f| watching?(f) }
        end
      end

      def watching?(file)
        file = @ph.xpath(file)

        if @files.member?(file)
          true
        elsif file.directory?
          false
        else
          ext = @ph.normalize_extension(file.extname)

          file.dirname.ascend do |dir|
            if @dirs.fetch(dir, []).include?(ext)
              break true
            elsif dir == @lcsp || dir.root?
              break false
            end
          end
        end
      end

      def directories_to_watch
        dtw = (@files + @dirs.keys).map { |f| @ph.existing_parent(f) }
        dtw.compact!
        dtw.uniq!

        @ph.filter_out_descendants(dtw)
      end

    class PathHelper
      def xpath(path)
        Pathname.new(path).expand_path
      end

      def normalize_extension(ext)
        ext.to_s.sub(/\A\./, '')
      end

      # Given a collection of Pathname objects returns the longest subpath
      # common to all of them, or +nil+ if there is none.
      def longest_common_subpath(paths)
        return if paths.empty?

        lcsp = Pathname.new(paths[0])

        paths[1..-1].each do |path|
          until ascendant_of?(lcsp, path)
            if lcsp.root?
              # If we get here a root directory is not an ascendant of path.
              # This may happen if there are paths in different drives on
              # Windows.
              return
            else
              lcsp = lcsp.parent
            end
          end
        end

        lcsp
      end

      # Returns the deepest existing ascendant, which could be the argument itself.
      def existing_parent(dir)
        dir.ascend do |ascendant|
          break ascendant if ascendant.directory?
        end
      end

      # Filters out directories which are descendants of others in the collection (stable).
      def filter_out_descendants(dirs)
        return dirs if dirs.length < 2

        dirs_sorted_by_nparts = dirs.sort_by { |dir| dir.each_filename.to_a.length }
        descendants = []

        until dirs_sorted_by_nparts.empty?
          dir = dirs_sorted_by_nparts.shift

          dirs_sorted_by_nparts.reject! do |possible_descendant|
            ascendant_of?(dir, possible_descendant) && descendants << possible_descendant
          end
        end

        # Array#- preserves order.
        dirs - descendants
      end

      private

        def ascendant_of?(base, other)
          base != other && other.ascend do |ascendant|
            break true if base == ascendant
          end
        end
    end
  end


  # A utility class for communicating a single message fixed length message from
  # a parent process to any number of forked processes child process.
  #
  # Each child process will receive a message once and only once.
  # There is no guaranteed time between when a response is requested and
  # a response received. This class does not entirely prevent race conditions
  # care should be taken while using the class
  #
  # Example:
  #
  #     pipe_sync = PipeSyncOnce.new
  #
  #     def boot(pipe_sync)
  #       puts "Reading Ready #{ Process.pid }"
  #       pipe_sync.listen_once do |value|
  #         puts "Process: #{ Process.pid }, value: #{value }"
  #       end
  #     end
  #
  #     fork do
  #       boot(pipe_sync)
  #       sleep 10
  #     end
  #
  #     fork do
  #       boot(pipe_sync)
  #       sleep 10
  #     end
  #
  #     sleep 1
  #     puts "Writing"
  #     pipe_sync.notify do
  #       'T'
  #     end
  #
  #     sleep 10
  #
  # Result:
  #
  #     => Reading Ready 90575
  #     => Reading Ready 905776
  #     => Writing
  #     => Process: 90576, value: T
  #     => Process: 90575, value: T
  class PipeSyncOnce # :nodoc: all

    def initialize(before_listen: nil, true_value: 'T', &block)
      @changed_reader, @changed_writer = IO.pipe
      @boot_reader,    @boot_writer    = IO.pipe
      @ack_reader,     @ack_writer     = IO.pipe
      @mutex         = Mutex.new
      @read_once     = nil
      @true_value    = true_value
      @read_length   = @true_value.length
      @parent_pid    = Process.pid
      @before_listen = before_listen
    end

    def notify(&block)
      return if Process.pid != @parent_pid

      Thread.new do
        loop do
          IO.select([@boot_reader])
          @boot_reader.read(@read_length)
          value = block.call
          raise "Value: #{value} is not appropriate lenght must be exactly #{ @read_length }" unless value.length == @read_length
          @changed_writer.write(value)
          IO.select([@ack_reader])
          @ack_reader.read(@read_length)
        end
      end
    end

    def listen_once(&block)
      return if Process.pid == @parent_pid
      @mutex.synchronize do
        return if @read_once
        @before_listen.call if @before_listen
        @boot_writer.write(@true_value)
        IO.select([@changed_reader])
        value = @changed_reader.read(@read_length)
        raise "Value: #{value} is not appropriate lenght must be exactly #{ @read_length }" unless value.length == @read_length

        block.call(value)
        @ack_writer.write(@true_value)
        @read_once = true
      end
    end
  end
  private_constant :PipeSyncOnce

end

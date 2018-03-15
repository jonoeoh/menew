# frozen_string_literal: true

module ActionDispatch
  module Http
    # Models uploaded files.
    #
    # The actual file is accessible via the +tempfile+ accessor, though some
    # of its interface is available directly for convenience.
    #
    # Uploaded files are temporary files whose lifespan is one request. When
    # the object is finalized Ruby unlinks the file, so there is no need to
    # clean them with a separate maintenance task.
    class UploadedFile
      # The basename of the file in the client.
      attr_accessor :original_filename

      # A string with the MIME type of the file.
      attr_accessor :content_type

      # A +Tempfile+ object with the actual uploaded file. Note that some of
      # its interface is available directly.
      attr_accessor :tempfile
      alias :to_io :tempfile
      delegate :all, to: :tempfile

      # A string with the headers of the multipart request.
      attr_accessor :headers

      def initialize(hash) # :nodoc:
        @tempfile = hash[:tempfile]
        raise(ArgumentError, ":tempfile is required") unless @tempfile

        if hash[:filename]
          @original_filename = hash[:filename].dup

          begin
            @original_filename.encode!(Encoding::UTF_8)
          rescue EncodingError
            @original_filename.force_encoding(Encoding::UTF_8)
          end
        else
          @original_filename = nil
        end

        @content_type      = hash[:type]
        @headers           = hash[:head]
      end
    end
  end
end

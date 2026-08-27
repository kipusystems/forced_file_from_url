# frozen_string_literal: true

require "open-uri"
require "tempfile"

module ForcedFileFromUrl
  module Cli
    module Fetch
      module_function

      def call(source, destination)
        io = nil
        io = URI.open(source.uri)
        path = materialize(io, destination)
        Artifact.new(source: source, path: path, byte_size: File.size(path))
      rescue StandardError => error
        failure_for(error)
      ensure
        io.close if io && !io.closed?
      end

      def materialize(io, destination)
        case destination
        in Destination::Fixed(path:)
          publish_fixed(io, path)
        in Destination::Scratch(prefix:, suffix:)
          publish_scratch(io, prefix, suffix)
        end
      end

      def publish_fixed(io, path)
        absolute = File.expand_path(path)
        tmp = nil
        tmp = Tempfile.create([".#{File.basename(absolute)}.", ".part"], File.dirname(absolute))
        begin
          IO.copy_stream(io, tmp)
          tmp.flush
          tmp.close
          File.rename(tmp.path, absolute)
        rescue
          tmp.close unless tmp.nil? || tmp.closed?
          File.unlink(tmp.path) if tmp && tmp.path && File.exist?(tmp.path)
          raise
        end
        path
      end

      def publish_scratch(io, prefix, suffix)
        # Tempfile.create has no unlink finalizer; Tempfile.new would delete this path at exit.
        file = nil
        file = Tempfile.create([prefix, suffix])
        IO.copy_stream(io, file)
        file.flush
        file.path
      ensure
        file.close if file && !file.closed?
      end

      def failure_for(error)
        case error
        when OpenURI::HTTPError
          Failure.new(kind: :http_error, message: error.message)
        when SocketError, EOFError,
             Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH,
             Errno::ETIMEDOUT, Errno::ECONNRESET
          Failure.new(kind: :network_error, message: error.message)
        when SystemCallError
          Failure.new(kind: :write_failed, message: error.message)
        else
          Failure.new(kind: :network_error, message: error.message)
        end
      end
    end
  end
end

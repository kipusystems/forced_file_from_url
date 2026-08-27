# frozen_string_literal: true

require "optparse"
require "uri"
require "forced_file_from_url/version"

module ForcedFileFromUrl
  module Cli
    Source = Data.define(:uri) do
      def to_s = uri.to_s
    end

    module Destination
      Fixed = Data.define(:path)
      Scratch = Data.define(:prefix, :suffix)
    end

    Artifact = Data.define(:source, :path, :byte_size)
    Failure = Data.define(:kind, :message) do
      def status = EXIT_STATUS.fetch(kind)
    end
    Notice = Data.define(:kind, :text)
    Invocation = Data.define(:source, :destination)
    Parsed = Data.define(:format, :request)
    Emission = Data.define(:stdout, :stderr, :status)

    EXIT_STATUS = {
      usage: 2,
      unsupported_scheme: 2,
      http_error: 1,
      network_error: 1,
      write_failed: 1
    }.freeze

    module Args
      module_function

      FETCHABLE_SCHEMES = %w[http https].freeze

      def parse(argv)
        format = format_of(argv)
        output_path = nil
        notice = nil
        parser = OptionParser.new do |o|
          o.banner = "Usage: forced_file_from_url [--json] [-o PATH] URL"
          o.on("--json") {}
          o.on("-o", "--output PATH") { |path| output_path = path }
          o.on("-h", "--help") { notice = Notice.new(kind: :help, text: o.help.chomp) }
          o.on("--version") { notice = Notice.new(kind: :version, text: ForcedFileFromUrl::VERSION) }
        end

        rest = parser.parse(argv.dup)
        return Parsed.new(format: format, request: notice) if notice
        return usage(format, "exactly one URL is required") unless rest.size == 1

        uri = URI.parse(rest.fetch(0))
        unless FETCHABLE_SCHEMES.include?(uri.scheme)
          return Parsed.new(
            format: format,
            request: Failure.new(kind: :unsupported_scheme, message: "unsupported scheme: #{uri.scheme.inspect}")
          )
        end

        source = Source.new(uri: uri)
        Parsed.new(format: format, request: Invocation.new(source: source, destination: destination_for(uri, output_path)))
      rescue OptionParser::ParseError, URI::InvalidURIError => e
        usage(format, e.message)
      end

      def format_of(argv)
        argv.include?("--json") ? :json : :text
      end

      def destination_for(uri, output_path)
        return Destination::Fixed.new(path: output_path) if output_path

        name = File.basename(uri.path.to_s)
        name = "download" if name.empty?
        suffix = File.extname(name)
        prefix = File.basename(name, suffix)
        prefix = "download" if prefix.empty?
        Destination::Scratch.new(prefix: prefix, suffix: suffix)
      end

      def usage(format, message)
        Parsed.new(format: format, request: Failure.new(kind: :usage, message: message))
      end
    end
  end
end

require_relative "cli/fetch"
require_relative "cli/render"

module ForcedFileFromUrl
  module Cli
    RENDERERS = { text: Render::Text, json: Render::Json }.freeze

    module_function

    def run(argv, out: $stdout, err: $stderr)
      parsed = Args.parse(argv)
      renderer = RENDERERS.fetch(parsed.format)
      outcome = case parsed.request
                in Invocation(source:, destination:) then Fetch.call(source, destination)
                in Failure | Notice => done then done
                end
      emission = renderer.call(outcome)
      out.write emission.stdout
      err.write emission.stderr
      emission.status
    end
  end
end

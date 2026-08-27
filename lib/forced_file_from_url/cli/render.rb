# frozen_string_literal: true

require "json"

module ForcedFileFromUrl
  module Cli
    module Render
      module Text
        module_function

        def call(outcome)
          case outcome
          in Artifact(path:)
            Emission.new(stdout: "#{path}\n", stderr: "", status: 0)
          in Failure => failure
            Emission.new(stdout: "", stderr: "forced_file_from_url: #{failure.message}\n", status: failure.status)
          in Notice(text:)
            Emission.new(stdout: "#{text}\n", stderr: "", status: 0)
          end
        end
      end

      module Json
        module_function

        def call(outcome)
          case outcome
          in Artifact(source:, path:, byte_size:)
            emit({ ok: true, url: source.to_s, path: path, bytes: byte_size }, 0)
          in Failure => failure
            emit({ ok: false, error: { kind: failure.kind.to_s, message: failure.message } }, failure.status)
          in Notice(kind:, text:)
            emit({ ok: true, kind: kind.to_s, text: text }, 0)
          end
        end

        def emit(payload, status)
          Emission.new(stdout: "#{JSON.generate(payload)}\n", stderr: "", status: status)
        end
      end
    end
  end
end

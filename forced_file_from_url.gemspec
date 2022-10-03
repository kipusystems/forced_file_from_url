# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'forced_file_from_url/version'

Gem::Specification.new do |spec|
  spec.name          = "forced_file_from_url"
  spec.version       = ForcedFileFromUrl::VERSION
  spec.authors       = ["Sampson Crowley"]
  spec.email         = ["sampson.crowley@kipuhealth.com"]
  spec.summary       = %q{Tiny hack to convert StringIO objects into Tempfile when using OpenURI to open files less than 10kb.}
  spec.description   = %q{Tiny hack to convert StringIO objects into Tempfile when using OpenURI to open files less than 10kb.}
  spec.homepage      = "https://github.com/kipuhealth/forced_file_from_url.git"
  spec.license       = "MIT"

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end

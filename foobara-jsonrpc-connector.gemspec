require_relative "version"

Gem::Specification.new do |spec|
  spec.name = "foobara-jsonrpc-connector"
  spec.version = Foobara::JsonrpcConnectorVersion::VERSION
  spec.authors = ["Miles Georgi"]
  spec.email = ["azimux@gmail.com"]

  spec.summary = "No description. Add one."
  spec.homepage = "https://github.com/foobara/jsonrpc-connector"
  spec.license = "MPL-2.0"
  spec.required_ruby_version = Foobara::JsonrpcConnectorVersion::MINIMUM_RUBY_VERSION

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*",
    "src/**/*",
    "LICENSE*.txt",
    "README.md",
    "CHANGELOG.md"
  ]

  spec.add_dependency "foobara", "~> 0.0.93"

  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
end

require_relative 'lib/minazuki/version'

Gem::Specification.new do |spec|
  spec.name          = "minazuki"
  spec.version       = Minazuki::VERSION
  spec.authors       = ["David Siaw"]
  spec.email         = ["davidsiaw@gmail.com"]

  spec.summary       = %q{builder}
  spec.description   = %q{builder}
  spec.homepage      = "https://github.com/davidsiaw/minazuki"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/davidsiaw/minazuki"
  spec.metadata["changelog_uri"] = "https://github.com/davidsiaw/minazuki"

  spec.files         = Dir['{data,exe,lib,bin}/**/*'] + %w[Gemfile ql.gemspec]
  spec.test_files    = Dir['{spec}/**/*']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport'
  spec.add_dependency 'bunny-tsort'
  spec.add_dependency 'erubis'
  spec.add_dependency 'method_source'
  spec.add_dependency 'rubocop'

  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end

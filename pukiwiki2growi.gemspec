# frozen_string_literal: true

require_relative 'lib/pukiwiki2growi/version'

Gem::Specification.new do |spec|
  spec.name          = 'pukiwiki2growi'
  spec.version       = Pukiwiki2growi::VERSION
  spec.authors       = ['netsugo']
  spec.email         = ['netsugo@users.noreply.github.com']

  spec.summary       = 'This is a tool for migrating from PukiWiki to GROWI.'
  spec.homepage      = 'https://github.com/netsugo/pukiwiki2growi'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'simplecov', '~> 0.10'

  spec.add_dependency 'json'
  spec.add_dependency 'mime-types'
  spec.add_dependency 'parallel'
  spec.add_dependency 'rest-client', '>= 2.0.0'
  spec.add_dependency 'ruby-progressbar'
  spec.add_dependency 'yaml'
end

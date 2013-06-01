# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aweplug/version'

Gem::Specification.new do |gem|
  gem.name          = "aweplug"
  gem.version       = Aweplug::VERSION
  gem.authors       = ["LightGuard"]
  gem.email         = ["lightguard.jp@gmail.com"]
  gem.description   = %q{A set of Awestruct extensions for building a project website}
  gem.summary       = %q{This set of Awestruct extensions includes helpful tools, 
                         extensions and helpers for building a website using Awestruct.
                         It includes extensions for accessing Github, JIRA, managing identities and others.}
  gem.homepage      = "https://github.com/awestruct/aweplug"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  #gem.add_dependency 'awestruct', '>= 0.5.1'
  gem.add_dependency 'octokit', '>= 1.24.0'
  gem.add_dependency 'faraday', '>= 0.8.7'
  gem.add_dependency 'faraday_middleware', '>= 0.9.0'

  gem.add_development_dependency 'guard-rspec', '~> 3.0.0'
  gem.add_development_dependency 'rake', '~> 10.0.4'
end

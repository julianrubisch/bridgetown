# frozen_string_literal: true

require_relative "../bridgetown-core/lib/bridgetown-core/version"

Gem::Specification.new do |spec|
  spec.name          = "bridgetown-model"
  spec.version       = Bridgetown::VERSION
  spec.author        = "Bridgetown Team"
  spec.email         = "maintainers@bridgetownrb.com"
  spec.summary       = "A Bridgetown plugin to wrap pages/documents in ActiveModel objects for use by Ruby/Rails CMSes."
  spec.homepage      = "https://github.com/bridgetownrb/bridgetown/tree/master/bridgetown-model"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r!^(test|script|spec|features)/!) }
  spec.require_paths = ["lib"]

  spec.add_dependency("bridgetown-core", Bridgetown::VERSION)
  spec.add_dependency("activemodel", "~> 6.0")
end

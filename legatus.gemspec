$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "legatus/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "legatus"
  s.version     = Legatus::VERSION
  s.authors     = ["rcpedro"]
  s.email       = ["rodettecpedro@gmail.com"]
  s.homepage    = "https://github.com/rcpedro/legatus"
  s.summary     = "Rails Business Directives"
  s.description = "Declare busness directives for actions in Rails."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 6.1"
  s.add_dependency "flexcon", "~> 0.1.0"

  s.add_development_dependency "sqlite3"
end

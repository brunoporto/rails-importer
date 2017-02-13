# $:.push File.expand_path("../lib", __FILE__)
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

# Maintain your gem's version:
require "rails_importer/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "rails-importer"
  spec.version     = RailsImporter::VERSION
  spec.authors     = ["Bruno Porto"]
  spec.email       = ["brunotporto@gmail.com"]
  spec.homepage    = "https://github.com/brunoporto/rails-importer"
  spec.summary     = "Rails Importer"
  spec.description = "Rails Importer"
  spec.license     = "MIT"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency 'rails', ['>= 3','<= 6']
  spec.add_dependency 'spreadsheet', '~> 0'

  # s.add_development_dependency "sqlite3"
end

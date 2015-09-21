$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "subscriptions/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "subscriptions"
  s.version     = Subscriptions::VERSION
  s.authors     = ["Ben McFadden"]
  s.email       = ["ben@forgeapps.com"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of Subscriptions."
  s.description = "TODO: Description of Subscriptions."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2"
  s.add_dependency "acts_as_list"
  s.add_dependency "sidekiq"
  s.add_dependency "friendly_id"
end

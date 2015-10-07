$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "subscriptions/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "subscriptions"
  s.version     = Subscriptions::VERSION
  s.authors     = ["Ben McFadden"]
  s.email       = ["ben@forgeapps.com"]
  s.homepage    = "https://github.com/Lightstock/Subscriptions"
  s.summary     = "Subscriptions is a work in progress."
  s.description = "Subscriptions is a work in progress, but is ultimately designed to become a drop-in subscription management and billing system."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2"
  s.add_dependency "acts_as_list"
  s.add_dependency "sidekiq"
  s.add_dependency "friendly_id"
end

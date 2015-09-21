module Subscriptions
  class Engine < ::Rails::Engine
    config.autoload_paths << File.expand_path('../../', __FILE__)

    isolate_namespace Subscriptions
  end
end

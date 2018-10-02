#
# Usage:
#   bundle exec rackup examples/ui/basic.ru -p 9999
#   bundle exec shotgun examples/ui/basic.ru -p 9999
#   http://localhost:9999/
#
require "pp"
require "logger"
require "pathname"

root_path = Pathname(__FILE__).dirname.join("..").expand_path
lib_path  = root_path.join("lib")
$:.unshift(lib_path)

require "flipper-u i"
require "flipper/adapters/v2/pstore"
require "active_support/notifications"

Flipper.register(:admins) { |actor|
  actor.respond_to?(:admin?) && actor.admin?
}

Flipper.register(:early_access) { |actor|
  actor.respond_to?(:early?) && actor.early?
}

# Setup logging of flipper calls.
if ENV["LOG"] == "1"
  $logger = Logger.new(STDOUT)
  require "flipper/instrumentation/log_subscriber"
  Flipper::Instrumentation::LogSubscriber.logger = $logger
end

adapter = Flipper::Adapters::V2::PStore.new
flipper = Flipper.new(adapter, instrumenter: ActiveSupport::Notifications)

# You can uncomment these to get some default data:
# flipper[:search_performance_another_long_thing].enable
# flipper[:gauges_tracking].enable
# flipper[:unused].disable
# flipper[:suits].enable_actor Flipper::Actor.new('1')
# flipper[:suits].enable_actor Flipper::Actor.new('6')
# flipper[:secrets].enable_group :admins
# flipper[:secrets].enable_group :early_access
# flipper[:logging].enable_percentage_of_time 5
# flipper[:new_cache].enable_percentage_of_actors 15
# flipper["a/b"].add

run Flipper::UI.app(flipper) { |builder|
  builder.use Rack::Session::Cookie, secret: "_super_secret"
}

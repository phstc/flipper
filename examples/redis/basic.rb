require 'pathname'
require 'logger'

root_path = Pathname(__FILE__).dirname.join('..').expand_path
lib_path  = root_path.join('lib')
$:.unshift(lib_path)

require 'flipper/adapters/v2/redis'
options = {}
if ENV['REDIS_URL']
  options[:url] = ENV['REDIS_URL']
end
client = Redis.new(options)
adapter = Flipper::Adapters::V2::Redis.new(client)
flipper = Flipper.new(adapter)

flipper[:stats].enable

if flipper[:stats].enabled?
  puts "Enabled!"
else
  puts "Disabled!"
end

flipper[:stats].disable

if flipper[:stats].enabled?
  puts "Enabled!"
else
  puts "Disabled!"
end

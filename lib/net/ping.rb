# By doing a "require 'net/ping'" you are requiring every subclass.  If you
# want to require a specific ping type only, do "require 'net/ping/tcp'",
# for example.
#
require 'rbconfig'

require_relative 'ping/tcp'
require_relative 'ping/udp'
require_relative 'ping/icmp'
require_relative 'ping/external'
require_relative 'ping/http'

RbConfig = Config unless Object.const_defined?(:RbConfig)

begin
  `busybox`
  RbConfig::CONFIG['busybox'] = true
rescue Errno::ENOENT
  RbConfig::CONFIG['busybox'] = false
end

if File::ALT_SEPARATOR
  begin
    require_relative 'ping/wmi'
  rescue LoadError => err
    gem_name = RUBY_ENGINE == 'jruby' ? 'win32ole-ffi' : 'win32ole'
    warn "Net::Ping::WMI is unavailable (#{err.message}). Run `gem install #{gem_name}` to enable it."
  end
end

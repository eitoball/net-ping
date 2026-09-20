######################################################################
# test_net_ping.rb
#
# Test suite for all the Ping subclasses. Note that the Ping::ICMP
# integration test only requires a privileged process on platforms
# other than macOS/Linux; see the require guard below.
######################################################################
require 'net/ping/icmp'
require 'test_net_ping_external'
require 'test_net_ping_gem_packaging'
require 'test_net_ping_http'
require 'test_net_ping_icmp_socket_selection'
require 'test_net_ping_tcp'
require 'test_net_ping_udp'

# SOCK_DGRAM ICMP sockets don't require elevated privileges on macOS or
# Linux, so the real ICMP integration tests only need to be gated behind
# a privilege check on Windows and other/unverified UNIX platforms. This
# mirrors the guard at the top of test_net_ping_icmp.rb itself.
if Net::Ping::ICMP.host_platform == :windows
  require 'win32/security'

  if Win32::Security.elevated_security?
    require 'test_net_ping_icmp'
  end
elsif [:macos, :linux].include?(Net::Ping::ICMP.host_platform)
  require 'test_net_ping_icmp'
elsif Net::Ping::ICMP.privileged_for_raw?
  require 'test_net_ping_icmp'
end

if File::ALT_SEPARATOR
  require 'test_net_ping_wmi'
end

class TC_Net_Ping < Test::Unit::TestCase
  def test_net_ping_version
    assert_equal(Gem::Specification.load('net-ping.gemspec').version.to_s, Net::Ping::VERSION)
  end
end

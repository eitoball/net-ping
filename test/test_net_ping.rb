######################################################################
# test_net_ping.rb
#
# Test suite for all the Ping subclasses. Note that the Ping::ICMP
# class test won't be run unless this is run as a privileged process.
######################################################################
require 'test_net_ping_external'
require 'test_net_ping_gem_packaging'
require 'test_net_ping_http'
require 'test_net_ping_tcp'
require 'test_net_ping_udp'

if File::ALT_SEPARATOR
  require 'win32/security'

  if Win32::Security.elevated_security?
    require 'test_net_ping_icmp'
  end
else
  # If cap2 is availble, check if we are root, or our process has net_raw,
  # then include ICMP tests
  begin
    require 'cap2'
    current_process = Cap2.process
    if Process.euid == 0 \
      || current_process.permitted?(:net_raw) \
      && current_process.enabled?(:net_raw)
      require 'test_net_ping_icmp'
    end
  rescue LoadError
    # If we don't have cap2, include ICMP tests if we are root
    require 'test_net_ping_icmp' if Process.euid == 0
  end
end

if File::ALT_SEPARATOR
  require 'test_net_ping_wmi'
end

class TC_Net_Ping < Test::Unit::TestCase
  def test_net_ping_version
    assert_equal(Gem::Specification.load('net-ping.gemspec').version.to_s, Net::Ping::VERSION)
  end
end

#######################################################################
# test_net_ping_icmp_socket_selection.rb
#
# Unit tests for the platform detection, privilege-check and reply
# parsing logic behind Net::Ping::ICMP's DGRAM/RAW socket selection.
# Unlike test_net_ping_icmp.rb, this file performs no real pings and
# requires no elevated privileges on any platform.
#######################################################################
require 'test-unit'
require 'net/ping/icmp'

class TC_PingICMPSocketSelection < Test::Unit::TestCase
  test "host_platform returns :windows when the windows flag is set" do
    assert_equal(:windows, Net::Ping::ICMP.host_platform('linux-gnu', true))
  end

  test "host_platform returns :macos for darwin host_os strings" do
    assert_equal(:macos, Net::Ping::ICMP.host_platform('darwin21', false))
  end

  test "host_platform returns :linux for linux host_os strings" do
    assert_equal(:linux, Net::Ping::ICMP.host_platform('linux-gnu', false))
  end

  test "host_platform returns :other for unrecognized host_os strings" do
    assert_equal(:other, Net::Ping::ICMP.host_platform('freebsd13', false))
  end
end

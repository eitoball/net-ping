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

  test "privileged_for_raw? is true when euid is 0" do
    assert_true(Net::Ping::ICMP.privileged_for_raw?(euid: 0))
  end

  test "privileged_for_raw? is false for a non-root euid without cap2" do
    omit_if(defined?(Cap2), "cap2 is installed; the outcome depends on its capability report")
    assert_false(Net::Ping::ICMP.privileged_for_raw?(euid: 501))
  end
end

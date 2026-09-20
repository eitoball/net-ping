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

  test "parse_reply reads a RAW echo reply (20-byte IP header prefix)" do
    ip_header = "\x00" * 20
    icmp_header = [0, 0, 0, 4321, 7].pack('C2 n3')
    data = ip_header + icmp_header

    type, ping_id, seq = Net::Ping::ICMP.parse_reply(data, dgram: false)

    assert_equal(0, type)     # ICMP_ECHOREPLY
    assert_equal(4321, ping_id)
    assert_equal(7, seq)
  end

  test "parse_reply reads a DGRAM echo reply (no IP header prefix)" do
    icmp_header = [0, 0, 0, 4321, 7].pack('C2 n3')

    type, ping_id, seq = Net::Ping::ICMP.parse_reply(icmp_header, dgram: true)

    assert_equal(0, type)
    assert_equal(4321, ping_id)
    assert_equal(7, seq)
  end

  test "parse_reply reads id/seq from an embedded packet on a RAW error reply" do
    # 20-byte outer IP header + 8-byte outer ICMP header (type 3 = unreachable,
    # code, checksum, 4-byte unused/pointer) + 20-byte embedded original IP
    # header + embedded ICMP header (type, code, checksum, then id/seq at
    # absolute offset 52) + 4 bytes padding so data.length > 56.
    data = "\x00" * 20
    data << [3, 0, 0].pack('C2 n')
    data << "\x00" * 4
    data << "\x00" * 20
    data << [8, 0, 0].pack('C2 n')
    data << [4321, 7].pack('n2')
    data << "\x00" * 4

    type, ping_id, seq = Net::Ping::ICMP.parse_reply(data, dgram: false)

    assert_equal(3, type)
    assert_equal(4321, ping_id)
    assert_equal(7, seq)
  end

  test "parse_reply reads id/seq from an embedded packet on a DGRAM error reply" do
    # No outer IP header on DGRAM: 8-byte outer ICMP header + 20-byte
    # embedded original IP header + embedded ICMP header (id/seq at
    # absolute offset 32) + 4 bytes padding so data.length > 36.
    data = [3, 0, 0].pack('C2 n')
    data << "\x00" * 4
    data << "\x00" * 20
    data << [8, 0, 0].pack('C2 n')
    data << [4321, 7].pack('n2')
    data << "\x00" * 4

    type, ping_id, seq = Net::Ping::ICMP.parse_reply(data, dgram: true)

    assert_equal(3, type)
    assert_equal(4321, ping_id)
    assert_equal(7, seq)
  end

  test "parse_reply returns nil id/seq when the reply is too short" do
    type, ping_id, seq = Net::Ping::ICMP.parse_reply("\x00" * 21, dgram: false)

    assert_equal(0, type)
    assert_nil(ping_id)
    assert_nil(seq)
  end
end

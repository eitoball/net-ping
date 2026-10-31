########################################################################
# test_net_ping_udp.rb
#
# Test case for the Net::Ping::UDP class. This should be run via the
# 'test' or 'test:udp' Rake tasks.
#
# If someone could provide me a host where a udp ping actually
# works (with a service check), I would appreciate it. :)
########################################################################
require 'test-unit'
require 'net/ping/udp'

class TC_Net_Ping_UDP < Test::Unit::TestCase
  def setup
    Net::Ping::UDP.service_check = false
    @host = '127.0.0.1'
    @udp  = Net::Ping::UDP.new(@host)
  end

  test "ping basic functionality" do
    assert_respond_to(@udp, :ping)
    assert_nothing_raised{ @udp.ping }
  end

  test "ping accepts a host as an argument" do
    assert_nothing_raised{ @udp.ping(@host) }
  end

  test "ping? is inherited" do
    assert_respond_to(@udp, :ping?)
  end

  test "pingecho is inherited" do
    assert_respond_to(@udp, :pingecho)
  end

  test "a successful udp ping returns true" do
    assert_true(@udp.ping?)
  end

  test "bind basic functionality" do
    assert_respond_to(@udp, :bind)
    assert_nothing_raised{ @udp.bind('127.0.0.1', 80) }
  end
   
  test "duration basic functionality" do
    assert_nothing_raised{ @udp.ping }
    assert_respond_to(@udp, :duration)
    assert_kind_of(Float, @udp.duration)
  end

  test "host basic functionality" do
    assert_respond_to(@udp, :host)
    assert_respond_to(@udp, :host=)
    assert_equal('127.0.0.1', @udp.host)
  end

  test "port basic functionality" do
    assert_respond_to(@udp, :port)
    assert_respond_to(@udp, :port=)
    assert_equal(7, @udp.port)
  end

  test "timeout basic functionality" do
    assert_respond_to(@udp, :timeout)
    assert_respond_to(@udp, :timeout=)
  end

  test "timeout default value is five" do
    assert_equal(5, @udp.timeout)
  end

  test "a nil timeout disables the timeout instead of raising" do
    @udp.timeout = nil
    assert_nothing_raised{ @udp.ping? }
  end

  test "a zero timeout disables the timeout instead of failing immediately" do
    @udp.timeout = 0
    assert_true(@udp.ping?)
  end

  test "ping times out when the remote port never replies" do
    silent_peer = UDPSocket.new
    silent_peer.bind('127.0.0.1', 0)
    port = silent_peer.addr[1]

    udp = Net::Ping::UDP.new('127.0.0.1', port, 1)
    start = Time.now
    assert_false(udp.ping?)
    elapsed = Time.now - start

    assert_true(elapsed < 2.5, "Actual elapsed: #{elapsed}")
    assert_kind_of(Timeout::Error, udp.exception)
    assert_nil(udp.duration)
  ensure
    silent_peer.close if silent_peer
  end

  test "exception basic functionality" do
    assert_respond_to(@udp, :exception)
  end

  test "the exception attribute returns nil if the ping is successful" do
    assert_true(@udp.ping?)
    assert_nil(@udp.exception)
  end

  test "the exception attribute is not nil if the ping is unsuccessful" do
    assert_false(@udp.ping?('www.ruby-lang.org'))
    assert_not_nil(@udp.exception)
  end

  test "warning basic functionality" do
    assert_respond_to(@udp, :warning)
  end

  test "the warning attribute returns nil if the ping is successful" do
    assert_true(@udp.ping?)
    assert_nil(@udp.warning)
  end
   
  test "service_check basic functionality" do
    assert_respond_to(Net::Ping::UDP, :service_check)
    assert_respond_to(Net::Ping::UDP, :service_check=)
  end

  test "service_check attribute has been set to false" do
    assert_false(Net::Ping::UDP.service_check)
  end
   
  test "service_check getter method does not accept arguments" do
    assert_raise(ArgumentError){ Net::Ping::UDP.service_check(1) }
  end

  test "service_check setter method only accepts boolean arguments" do
    assert_raise(ArgumentError){ Net::Ping::UDP.service_check = 1 }
  end

  def teardown
    @host = nil
    @udp  = nil
  end
end

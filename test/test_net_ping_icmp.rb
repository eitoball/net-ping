#######################################################################
# test_net_ping_icmp.rb
#
# Test case for the Net::PingICMP class. You must run this test case
# with root privileges on UNIX systems. This should be run via the
# 'test' or 'test:icmp' Rake task.
#######################################################################
require 'test-unit'
require 'net/ping/icmp'
require 'thread'

if Net::Ping::ICMP.host_platform == :windows
  require 'win32/security'

  unless Win32::Security.elevated_security?
    raise "The test:icmp task must be run with elevated security rights"
  end
elsif ![:macos, :linux].include?(Net::Ping::ICMP.host_platform)
  unless Net::Ping::ICMP.privileged_for_raw?
    raise StandardError, 'requires root privileges or setcap net_raw'
  end
end

class TC_PingICMP < Test::Unit::TestCase
  def self.startup
    @@jruby = RUBY_PLATFORM == 'java'
  end

  def setup
    @host = '127.0.0.1' # 'localhost'
    @icmp = Net::Ping::ICMP.new(@host)
    @concurrency = 2
  end

  test "icmp ping basic functionality" do
    assert_respond_to(@icmp, :ping)
    omit_if(@@jruby)
    assert_nothing_raised{ @icmp.ping }
  end

  test "icmp ping accepts a host" do
    omit_if(@@jruby)
    assert_nothing_raised{ @icmp.ping(@host) }
  end

  test "icmp ping returns a float" do
    omit_if(@@jruby)
    assert_kind_of(Float, @icmp.ping)
    assert_kind_of(Float, @icmp.ping(@host))
  end

  test "icmp ping of local host is successful" do
    omit_if(@@jruby)
    assert_true(Net::Ping::ICMP.new(@host).ping?)
    assert_true(Net::Ping::ICMP.new('127.0.0.1').ping?)
  end

  test "icmp ping of local host uses a DGRAM socket on macos and linux" do
    omit_if(@@jruby)
    platform = Net::Ping::ICMP.host_platform
    omit_unless([:macos, :linux].include?(platform), "DGRAM is only expected on macos/linux")

    icmp = Net::Ping::ICMP.new(@host)
    socket, _dgram = icmp.send(:create_socket)
    socket_type = socket.getsockopt(Socket::SOL_SOCKET, Socket::SO_TYPE).int
    socket.close

    # Note: the second value returned by create_socket ("dgram") is NOT
    # "is this a SOCK_DGRAM socket" -- see the comment above
    # Net::Ping::ICMP#create_socket. It is false on macOS even though a
    # real SOCK_DGRAM socket is opened, so we check socket.type directly.
    assert_equal(Socket::SOCK_DGRAM, socket_type, "expected a DGRAM socket on #{platform}")
  end

  test "threaded icmp ping returns expected results" do
    omit_if(@@jruby)
    # ips = ['8.8.4.4', '8.8.9.9', '127.0.0.1', '8.8.8.8', '8.8.8.9']
    ips = ['127.0.0.1', '8.8.8.9']
    queue = Queue.new
    threads = []

    ips.each{ |ip| queue <<  ip }

    @concurrency.times{
      threads << Thread.new(queue) do |q|
        ip = q.pop
        icmp = Net::Ping::ICMP.new(ip, nil, 1)
        if ip =~ /\.9$/
          assert_false(icmp.ping?, "#{ip} should not be pingable")
        else
          assert_true(icmp.ping?, "#{ip} should be pingable")
        end
      end
    }

    threads.each{ |t| t.join }
  end

  test "ping? is inherited" do
    assert_respond_to(@icmp, :ping?)
  end

  test "pingecho is inherited" do
    assert_respond_to(@icmp, :pingecho)
  end

  test "icmp ping fails if host is invalid" do
    omit_if(@@jruby)
    assert_false(Net::Ping::ICMP.new('bogus').ping?)
    assert_false(Net::Ping::ICMP.new('http://www.asdfhjklasdfhlkj.com').ping?)
  end

  test "bind method basic functionality" do
    assert_respond_to(@icmp, :bind)
    assert_nothing_raised{ @icmp.bind(Socket.gethostname) }
    assert_nothing_raised{ @icmp.bind(Socket.gethostname, 80) }
  end

  test "duration method basic functionality" do
    omit_if(@@jruby)
    assert_nothing_raised{ @icmp.ping }
    assert_respond_to(@icmp, :duration)
    assert_kind_of(Float, @icmp.duration)
  end

  test "host getter method basic functionality" do
    assert_respond_to(@icmp, :host)
    assert_equal(@host, @icmp.host)
  end

  test "host setter method basic functionality" do
    assert_respond_to(@icmp, :host=)
    assert_nothing_raised{ @icmp.host = '192.168.0.1' }
    assert_equal(@icmp.host, '192.168.0.1')
  end

  test "port method basic functionality" do
    assert_respond_to(@icmp, :port)
    assert_equal(nil, @icmp.port)
  end

  test "timeout getter method basic functionality" do
    assert_respond_to(@icmp, :timeout)
    assert_equal(5, @icmp.timeout)
  end

  test "timeout setter method basic functionality" do
    assert_respond_to(@icmp, :timeout=)
    assert_nothing_raised{ @icmp.timeout = 7 }
    assert_equal(7, @icmp.timeout)
  end

  test "timeout works as expected" do
    omit_if(@@jruby)
    icmp = Net::Ping::ICMP.new('8.8.8.8', nil, 0.000001)
    assert_false(icmp.ping?)
    assert_kind_of(Timeout::Error, icmp.exception)
  end

  test "exception method basic functionality" do
    assert_respond_to(@icmp, :exception)
  end

  test "exception method returns nil if no ping has happened yet" do
    assert_nil(@icmp.exception)
  end

  test "warning method basic functionality" do
    assert_respond_to(@icmp, :warning)
  end

  test "data_size getter method basic functionality" do
    assert_respond_to(@icmp, :data_size)
    assert_nothing_raised{ @icmp.data_size }
    assert_kind_of(Numeric, @icmp.data_size)
  end

  test "data_size returns expected value" do
    assert_equal(56, @icmp.data_size)
  end

  test "data_size setter method basic functionality" do
    assert_respond_to(@icmp, :data_size=)
    assert_nothing_raised{ @icmp.data_size = 22 }
  end

  test "setting an odd data_size is valid" do
    omit_if(@@jruby)
    assert_nothing_raised{ @icmp.data_size = 57 }
    assert_kind_of(Float, @icmp.ping)
  end

  def teardown
    @host = nil
    @icmp = nil
    @concurrency = nil
  end

  def self.shutdown
    @@jruby = nil
  end
end

require File.join(File.dirname(__FILE__), 'ping')
require 'rbconfig'

if File::ALT_SEPARATOR
  require 'win32/security'
end

# The Net module serves as a namespace only.
module Net

  # The Net::Ping::ICMP class encapsulates an icmp ping.
  class Ping::ICMP < Ping
    ICMP_ECHOREPLY = 0 # Echo reply
    ICMP_ECHO      = 8 # Echo request
    ICMP_SUBCODE   = 0

    # You cannot set or change the port value. A value of 0 is always
    # used internally for ICMP pings.
    #
    undef_method :port=

    # Returns the data size, i.e. number of bytes sent on the ping. The
    # default size is 56.
    #
    attr_reader :data_size

    # Returns a symbol describing which ICMP socket strategy to use for
    # the current platform: :windows, :macos, :linux, or :other.
    #
    # The arguments exist purely so tests can exercise every branch
    # without needing to run on every platform.
    #
    def self.host_platform(host_os = RbConfig::CONFIG['host_os'], windows = !!File::ALT_SEPARATOR)
      return :windows if windows

      case host_os
        when /darwin/i
          :macos
        when /linux/i
          :linux
        else
          :other
      end
    end

    # Returns true if the current process is allowed to open a SOCK_RAW
    # ICMP socket: either it's running as root, or (on platforms with the
    # optional cap2 gem available) it holds an enabled CAP_NET_RAW
    # capability.
    #
    def self.privileged_for_raw?(euid: Process.euid)
      begin
        require 'cap2'
        current_process = Cap2.process
        euid == 0 \
          || current_process.permitted?(:net_raw) \
          && current_process.enabled?(:net_raw)
      rescue LoadError
        euid == 0
      end
    end

    # Extracts [type, ping_id, seq] from a raw ICMP reply payload as
    # returned by Socket#recvfrom. RAW sockets receive the IPv4 header
    # in front of the ICMP message; DGRAM sockets don't, so the offsets
    # shift back by the 20-byte IPv4 header size.
    #
    def self.parse_reply(data, dgram: false)
      type_offset, id_offset, error_id_offset = dgram ? [0, 4, 32] : [20, 24, 52]

      type = data[type_offset, 2].unpack('C2').first
      ping_id = nil
      seq = nil

      case type
        when ICMP_ECHOREPLY
          if data.length >= id_offset + 4
            ping_id, seq = data[id_offset, 4].unpack('n3')
          end
        else
          if data.length > error_id_offset + 4
            ping_id, seq = data[error_id_offset, 4].unpack('n3')
          end
      end

      [type, ping_id, seq]
    end

    # Creates and returns a new Ping::ICMP object.  This is similar to its
    # superclass constructor, but must be created with root privileges (on
    # UNIX systems), and the port value is ignored.
    #
    def initialize(host=nil, port=nil, timeout=5)
      begin
        # If we have cap2, but not are root, or have net_raw, raise an error
        require 'cap2'
        current_process = Cap2.process
        unless Process.euid == 0 \
          || current_process.permitted?(:net_raw) \
          && current_process.enabled?(:net_raw)
          raise StandardError, 'requires root privileges or setcap net_raw'
        end
      rescue LoadError
        # Without cap2, raise error if we are not root
        unless Process.euid == 0
          raise StandardError, 'requires root privileges or setcap net_raw'
        end
      end

      if File::ALT_SEPARATOR
        unless Win32::Security.elevated_security?
          raise 'requires elevated security'
        end
      end

      @seq = 0
      @bind_port = 0
      @bind_host = nil
      @data_size = 56
      @data = ''

      0.upto(@data_size){ |n| @data << (n % 256).chr }

      @ping_id = (Thread.current.object_id ^ Process.pid) & 0xffff

      super(host, port, timeout)
      @port = nil # This value is not used in ICMP pings.
    end

    # Sets the number of bytes sent in the ping method.
    #
    def data_size=(size)
      @data_size = size
      @data = ''
      0.upto(size){ |n| @data << (n % 256).chr }
    end

    # Associates the local end of the socket connection with the given
    # +host+ and +port+. The default port is 0.
    #
    def bind(host, port = 0)
      @bind_host = host
      @bind_port = port
    end

    # Pings the +host+ specified in this method or in the constructor.  If a
    # host was not specified either here or in the constructor, an
    # ArgumentError is raised.
    #
    def ping(host = @host)
      super(host)
      bool = false

      socket = Socket.new(
        Socket::PF_INET,
        Socket::SOCK_RAW,
        Socket::IPPROTO_ICMP
      )

      if @bind_host
        saddr = Socket.pack_sockaddr_in(@bind_port, @bind_host)
        socket.bind(saddr)
      end

      @seq = (@seq + 1) % 65536
      pstring = 'C2 n3 A' << @data_size.to_s
      timeout = @timeout

      checksum = 0
      msg = [ICMP_ECHO, ICMP_SUBCODE, checksum, @ping_id, @seq, @data].pack(pstring)

      checksum = checksum(msg)
      msg = [ICMP_ECHO, ICMP_SUBCODE, checksum, @ping_id, @seq, @data].pack(pstring)

      begin
        saddr = Socket.pack_sockaddr_in(0, host)
      rescue Exception
        socket.close unless socket.closed?
        return bool
      end

      start_time = Time.now

      socket.send(msg, 0, saddr) # Send the message

      begin
        Timeout.timeout(@timeout){
          while true
            io_array = select([socket], nil, nil, timeout)

            if io_array.nil? || io_array[0].empty?
              raise Timeout::Error if io_array.nil?
              return false
            end

            ping_id = nil
            seq = nil

            data = socket.recvfrom(1500).first
            type = data[20, 2].unpack('C2').first

            case type
              when ICMP_ECHOREPLY
                if data.length >= 28
                  ping_id, seq = data[24, 4].unpack('n3')
                end
              else
                if data.length > 56
                  ping_id, seq = data[52, 4].unpack('n3')
                end
            end

            if ping_id == @ping_id && seq == @seq && type == ICMP_ECHOREPLY
              bool = true
              break
            end
          end
        }
      rescue Exception => err
        @exception = err
      ensure
        socket.close if socket
      end

      # There is no duration if the ping failed
      @duration = Time.now - start_time if bool
    end

    private

    # Perform a checksum on the message.  This is the sum of all the short
    # words and it folds the high order bits into the low order bits.
    #
    def checksum(msg)
      length    = msg.length
      num_short = length / 2
      check     = 0

      msg.unpack("n#{num_short}").each do |short|
        check += short
      end

      if length % 2 > 0
        check += msg[length-1, 1].unpack('C').first << 8
      end

      check = (check >> 16) + (check & 0xffff)
      return (~((check >> 16) + check) & 0xffff)
    end
  end
end

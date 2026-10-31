#######################################################################
# test_net_ping_lib.rb
#
# Test case for the lib/net/ping.rb aggregator require.
#######################################################################
require 'open3'
require 'test-unit'

class TestNetPingLib < Test::Unit::TestCase
  ROOT = File.expand_path('..', __dir__)

  def test_require_tolerates_a_missing_wmi_dependency_on_windows
    omit_if(File::ALT_SEPARATOR, 'win32ole/win32ole-ffi may genuinely be installed here')

    script = <<~'RUBY'
      File.send(:remove_const, :ALT_SEPARATOR)
      File.const_set(:ALT_SEPARATOR, '\\')
      require 'net/ping'
      puts defined?(Net::Ping::WMI).inspect
    RUBY

    out, err, status = Open3.capture3(Gem.ruby, '-Ilib', '-e', script, chdir: ROOT)

    assert_true(status.success?, err)
    assert_equal('nil', out.strip)
    assert_match(/win32ole/, err)
  end
end

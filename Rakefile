require 'rake'
require 'rake/clean'
require 'rake/testtask'
include Object.const_defined?(:RbConfig) ? RbConfig : Config

CLEAN.include("**/*.gem", "**/*.rbc")

GEMSPEC_FILES = %w[
  net-ping.gemspec
  net-ping-universal-linux.gemspec
  net-ping-universal-mingw-ucrt.gemspec
].freeze

EXPECTED_GEM_METADATA = {
  'net-ping.gemspec' => ['ruby', {}],
  'net-ping-universal-linux.gemspec' => ['universal-linux', {'cap2' => '>= 0.2.2'}],
  'net-ping-universal-mingw-ucrt.gemspec' => [
    'universal-mingw-ucrt',
    {'win32-security' => '>= 0.2.0', 'win32ole' => '>= 1.8.8'}
  ]
}.freeze

def load_gem_specifications
  GEMSPEC_FILES.map do |path|
    spec = Gem::Specification.load(path)
    abort("Unable to load #{path}") unless spec
    spec
  end
end

def with_unbundled_env
  if defined?(Bundler) && Bundler.respond_to?(:with_unbundled_env)
    Bundler.with_unbundled_env { yield }
  elsif defined?(Bundler) && Bundler.respond_to?(:with_clean_env)
    Bundler.with_clean_env { yield }
  else
    yield
  end
end

def platform_installable?(spec)
  if Gem::Platform.respond_to?(:installable?)
    Gem::Platform.installable?(spec)
  else
    Gem::Platform.match(spec.platform)
  end
end

def select_install_specification(specifications = load_gem_specifications)
  specific = specifications.find do |spec|
    spec.platform != Gem::Platform::RUBY && platform_installable?(spec)
  end
  spec = specific || specifications.find { |item| item.platform == Gem::Platform::RUBY }
  abort('Unable to find a Ruby fallback gem specification') unless spec
  spec
end

namespace 'gem' do
  desc 'Create the net-ping gem artifacts (ruby, universal-linux, universal-mingw-ucrt)'
  task :create => [:clean] do
    specifications = load_gem_specifications
    if Gem::VERSION.to_f < 2.0
      specifications.each do |spec|
        Gem::Builder.new(spec).build
      end
    else
      require 'rubygems/package'
      specifications.each do |spec|
        Gem::Package.build(spec)
      end
    end
  end

  desc 'Validate the net-ping gem artifacts'
  task :check do
    require 'rubygems/package'

    EXPECTED_GEM_METADATA.each do |path, expectation|
      expected_platform, expected_dependencies = expectation
      artifact = Gem::Specification.load(path).file_name
      packaged_spec = Gem::Package.new(artifact).spec
      actual_dependencies = packaged_spec.runtime_dependencies.each_with_object({}) do |dependency, memo|
        memo[dependency.name] = dependency.requirement.to_s
      end

      if packaged_spec.platform.to_s != expected_platform
        abort("#{artifact}: expected platform #{expected_platform.inspect}, got #{packaged_spec.platform.to_s.inspect}")
      end

      if actual_dependencies != expected_dependencies
        abort("#{artifact}: expected dependencies #{expected_dependencies.inspect}, got #{actual_dependencies.inspect}")
      end
    end
  end

  desc 'Install the net-ping gem'
  task :install => [:create] do
    spec = select_install_specification

    install_command = if RUBY_PLATFORM == 'java'
      ['jruby', '-S', 'gem', 'install', '-l', spec.file_name]
    else
      ['gem', 'install', '-l', spec.file_name]
    end

    with_unbundled_env do
      sh(*install_command)
    end
  end
end

namespace 'example' do
  desc 'Run the external ping example program'
  task :external do
     ruby '-Ilib examples/example_pingexternal.rb'
  end

  desc 'Run the http ping example program'
  task :http do
     ruby '-Ilib examples/example_pinghttp.rb'
  end

  desc 'Run the tcp ping example program'
  task :tcp do
     ruby '-Ilib examples/example_pingtcp.rb'
  end

  desc 'Run the udp ping example program'
  task :udp do
     ruby '-Ilib examples/example_pingudp.rb'
  end
end

Rake::TestTask.new do |t|
   t.libs << 'test'
   t.warning = true
   t.verbose = true
   t.test_files = FileList['test/test_net_ping.rb']
end

namespace 'test' do
  Rake::TestTask.new('external') do |t|
     t.warning = true
     t.verbose = true
     t.test_files = FileList['test/test_net_ping_external.rb']
  end

  Rake::TestTask.new('http') do |t|
     t.warning = true
     t.verbose = true
     t.test_files = FileList['test/test_net_ping_http.rb']
  end

  Rake::TestTask.new('icmp') do |t|
     t.warning = true
     t.verbose = true
     t.test_files = FileList['test/test_net_ping_icmp.rb']
  end

  Rake::TestTask.new('tcp') do |t|
     t.warning = true
     t.verbose = true
     t.test_files = FileList['test/test_net_ping_tcp.rb']
  end

  Rake::TestTask.new('udp') do |t|
     t.warning = true
     t.verbose = true
     t.test_files = FileList['test/test_net_ping_udp.rb']
  end

  Rake::TestTask.new('wmi') do |t|
     t.warning = true
     t.verbose = true
     t.test_files = FileList['test/test_net_ping_wmi.rb']
  end
end

task :default => :test

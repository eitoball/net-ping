require 'open3'
require 'rake'
require 'rubygems/package'
require 'test/unit'

class TestNetPingGemPackaging < Test::Unit::TestCase
  GemfileRecorder = Struct.new(:dependencies) do
    def initialize
      super({})
    end

    def source(*); end
    def gemspec(*); end

    def gem(name, *requirements)
      dependencies[name] = requirements
    end
  end

  EXPECTATIONS = {
    'net-ping.gemspec' => ['ruby', {}],
    'net-ping-universal-linux.gemspec' => ['universal-linux', {'cap2' => '>= 0.2.2'}],
    'net-ping-universal-mingw-ucrt.gemspec' => [
      'universal-mingw-ucrt',
      {'win32-security' => '>= 0.2.0', 'win32ole' => '>= 1.8.8'}
    ]
  }.freeze
  ROOT = File.expand_path('..', __dir__)

  def test_platforms_and_runtime_dependencies
    gem_files = nil
    specifications = load_specifications

    Dir.chdir(ROOT) do
      gem_files = specifications.map { |_, spec| Gem::Package.build(spec) }
    end

    specifications.each do |path, spec|
      expected_platform, expected_dependencies = EXPECTATIONS.fetch(path)
      packaged_spec = Gem::Package.new(File.join(ROOT, spec.file_name)).spec
      dependencies = packaged_spec.runtime_dependencies.each_with_object({}) do |dependency, memo|
        memo[dependency.name] = dependency.requirement.to_s
      end

      assert_equal(expected_dependencies, dependencies, path)

      if platform_round_trips_for_test?(expected_platform)
        assert_equal(expected_platform, packaged_spec.platform.to_s, path)
      else
        omit("this RubyGems (#{Gem::VERSION}) cannot round-trip the #{expected_platform.inspect} platform string")
      end
    end
  ensure
    delete_files(gem_files)
  end

  def test_rake_create_builds_all_expected_artifacts_and_validates_them
    stdout, stderr, status = run_rake('clean', 'gem:create', 'gem:check')

    assert(status.success?, [stdout, stderr].join)
    assert_equal(expected_gem_files, built_gem_files)
  ensure
    delete_files(built_gem_files)
  end

  def test_gem_create_excludes_generated_artifacts_from_spec_files_and_keeps_bundle_exec_usable
    stdout, stderr, status = run_rake('clean', 'gem:create')

    assert(status.success?, [stdout, stderr].join)
    load_specifications.each do |path, spec|
      assert_equal([], spec.files.grep(/\.gem$/).sort, path)
    end

    stdout, stderr, status = run_bundle_exec('ruby', '-e', 'puts :bundle_exec_after_gem_create')
    assert(status.success?, [stdout, stderr].join)
    assert_equal("bundle_exec_after_gem_create\n", stdout)
  ensure
    delete_files(built_gem_files)
  end

  def test_gem_create_excludes_non_distributable_project_files_from_spec_files
    load_specifications.each do |path, spec|
      non_distributable = spec.files.select do |f|
        f == 'CLAUDE.md' || f == 'docs' || f.start_with?('docs/')
      end

      assert_equal([], non_distributable, path)
    end
  end

  def test_gem_check_uses_fixed_expectations_instead_of_loaded_specifications
    stdout, stderr, status = run_rake('clean', 'gem:create')

    assert(status.success?, [stdout, stderr].join)

    specifications = load_specifications.map do |path, spec|
      if path == 'net-ping-universal-linux.gemspec'
        [path, specification_with_reported_platform(spec, Gem::Platform::RUBY)]
      else
        [path, spec]
      end
    end

    with_rakefile do |application|
      with_stubbed_load_gem_specifications(specifications.map(&:last)) do
        assert_nothing_raised { application['gem:check'].invoke }
      end
    end
  ensure
    delete_files(built_gem_files)
  end

  def test_gem_install_selects_local_compatible_specification
    with_rakefile do
      assert_equal(expected_install_platform, select_install_specification.platform.to_s)
    end
  end

  def test_gemfile_adds_win32_security_only_for_windows_development
    assert_nil(gemfile_dependencies_for(win_platform: false)['win32-security'])
    assert_equal(
      ['>= 0.2.0'],
      gemfile_dependencies_for(win_platform: true)['win32-security']
    )
  end

  def test_with_unbundled_env_prefers_with_unbundled_env_when_available
    calls = []

    with_rakefile do
      with_stubbed_bundler_methods(
        :with_unbundled_env => proc do |&block|
          calls << :with_unbundled_env
          block.call
        end,
        :with_clean_env => proc do |&block|
          calls << :with_clean_env
          block.call
        end
      ) do
        assert_equal(:ran, with_unbundled_env { calls << :block; :ran })
      end
    end

    assert_equal([:with_unbundled_env, :block], calls)
  end

  def test_with_unbundled_env_falls_back_to_with_clean_env
    calls = []

    with_rakefile do
      with_stubbed_bundler_methods(
        :with_clean_env => proc do |&block|
          calls << :with_clean_env
          block.call
        end
      ) do
        assert_equal(:ran, with_unbundled_env { calls << :block; :ran })
      end
    end

    assert_equal([:with_clean_env, :block], calls)
  end

  def test_platform_installable_prefers_installable_when_available
    spec = Struct.new(:platform).new(:preferred_platform)
    calls = []

    with_rakefile do
      with_stubbed_platform_methods(
        :installable? => proc do |candidate|
          calls << [:installable?, candidate.platform]
          true
        end,
        :match => proc do |platform|
          calls << [:match, platform]
          false
        end
      ) do
        assert_equal(true, platform_installable?(spec))
      end
    end

    assert_equal([[:installable?, :preferred_platform]], calls)
  end

  def test_platform_installable_falls_back_to_match
    spec = Struct.new(:platform).new(:fallback_platform)
    calls = []

    with_rakefile do
      with_stubbed_platform_methods(
        :match => proc do |platform|
          calls << [:match, platform]
          true
        end
      ) do
        assert_equal(true, platform_installable?(spec))
      end
    end

    assert_equal([[:match, :fallback_platform]], calls)
  end

  private

  def load_specifications
    Dir.chdir(ROOT) do
      EXPECTATIONS.keys.map do |path|
        assert(File.exist?(path), "#{path} does not exist")

        loaded_spec = Gem::Specification.load(path)
        spec = loaded_spec ? loaded_spec.dup : nil
        assert_not_nil(spec, "expected #{path} to load")

        [path, spec]
      end
    end
  end

  def expected_gem_files
    load_specifications.map { |_, spec| spec.file_name }.sort
  end

  def built_gem_files
    Dir.chdir(ROOT) { Dir['net-ping-*.gem'].sort }
  end

  def expected_install_platform
    specifications = load_specifications.map(&:last)
    specific = specifications.find do |spec|
      spec.platform != Gem::Platform::RUBY && platform_installable_for_test?(spec)
    end
    (specific || specifications.find { |spec| spec.platform == Gem::Platform::RUBY }).platform.to_s
  end

  def run_rake(*tasks, env: {})
    Open3.capture3(env, Gem.ruby, '-S', 'bundle', 'exec', 'rake', *tasks, chdir: ROOT)
  end

  def run_bundle_exec(*command, env: {})
    Open3.capture3(env, Gem.ruby, '-S', 'bundle', 'exec', *command, chdir: ROOT)
  end

  def with_rakefile
    original = Rake.application
    application = Rake::Application.new
    Rake.application = application

    Dir.chdir(ROOT) do
      load File.join(ROOT, 'Rakefile')
      yield(application)
    end
  ensure
    Rake.application = original
  end

  def gemfile_dependencies_for(win_platform:)
    recorder = GemfileRecorder.new
    singleton_class = class << Gem; self; end
    original = singleton_class.instance_method(:win_platform?)
    singleton_class.send(:define_method, :win_platform?) { win_platform }
    recorder.instance_eval(File.read(File.join(ROOT, 'Gemfile')), File.join(ROOT, 'Gemfile'))

    recorder.dependencies
  ensure
    singleton_class.send(:define_method, :win_platform?, original) if singleton_class && original
  end

  def delete_files(paths)
    Array(paths).each do |path|
      file = File.join(ROOT, path)
      File.delete(file) if File.exist?(file)
    end
  end

  def specification_with_reported_platform(spec, platform)
    file_name = spec.file_name
    mutated = spec.dup
    mutated.platform = platform
    mutated.define_singleton_method(:file_name) { file_name }
    mutated
  end

  def with_stubbed_load_gem_specifications(specifications)
    original = Object.instance_method(:load_gem_specifications)
    Object.send(:remove_method, :load_gem_specifications)
    Object.send(:define_method, :load_gem_specifications) { specifications }
    Object.send(:private, :load_gem_specifications)
    yield
  ensure
    Object.send(:remove_method, :load_gem_specifications)
    Object.send(:define_method, :load_gem_specifications, original)
    Object.send(:private, :load_gem_specifications)
  end

  def with_stubbed_bundler_methods(methods)
    bundler = Module.new
    methods.each do |name, implementation|
      bundler.define_singleton_method(name, &implementation)
    end

    with_replaced_constant(Object, :Bundler, bundler) do
      yield
    end
  end

  def with_stubbed_platform_methods(methods)
    platform = Module.new
    methods.each do |name, implementation|
      platform.define_singleton_method(name, &implementation)
    end
    platform.const_set(:RUBY, Gem::Platform::RUBY)

    with_replaced_constant(Gem, :Platform, platform) do
      yield
    end
  end

  def with_replaced_constant(container, name, replacement)
    original = container.const_get(name) if container.const_defined?(name, false)
    container.send(:remove_const, name) if container.const_defined?(name, false)
    container.const_set(name, replacement)
    yield
  ensure
    container.send(:remove_const, name) if container.const_defined?(name, false)
    if original
      container.const_set(name, original)
    end
  end

  def platform_round_trips_for_test?(platform_string)
    Gem::Platform.new(platform_string).to_s == platform_string
  end

  def platform_installable_for_test?(spec)
    if Gem::Platform.respond_to?(:installable?)
      Gem::Platform.installable?(spec)
    else
      Gem::Platform.match(spec.platform)
    end
  end
end

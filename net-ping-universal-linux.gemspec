spec = Gem::Specification.load('net-ping.gemspec').dup
spec.platform = Gem::Platform.new(['universal', 'linux'])
spec.add_dependency('cap2', '>= 0.2.2')
spec

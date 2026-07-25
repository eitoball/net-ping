spec = Gem::Specification.load('net-ping.gemspec').dup
spec.platform = Gem::Platform.new(['universal', 'mingw-ucrt'])
spec.add_dependency('win32-security', '>= 0.2.0')

# No longer a default gem as of Ruby 4.0. Used by the WMI ping class.
spec.add_dependency('win32ole', '>= 1.8.8')
spec

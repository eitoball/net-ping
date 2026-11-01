source 'https://rubygems.org'
gemspec
gem 'win32-security', '>= 0.2.0' if Gem.win_platform?

# Used by the WMI ping class. No longer a default gem as of Ruby 4.0, and
# win32ole's C extension does not build on JRuby, so use the pure-Ruby
# win32ole-ffi gem there instead.
if Gem.win_platform?
  if RUBY_ENGINE == 'jruby'
    gem 'win32ole-ffi', '>= 0.1.0'
  else
    gem 'win32ole', '>= 1.8.8'
  end
end

gem 'cap2', '>= 0.2.2' if RUBY_PLATFORM =~ /linux/i

# byebug's C extension does not build on JRuby.
gem 'pry-byebug', '>= 0' unless RUBY_ENGINE == 'jruby'

# Validates sig/**/*.rbs. Requires Ruby >= 3.2.
gem 'rbs', '>= 3', require: false if RUBY_VERSION >= '3.2'

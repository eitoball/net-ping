source 'https://rubygems.org'
gemspec
gem 'win32-security', '>= 0.2.0' if Gem.win_platform?

# No longer a default gem as of Ruby 4.0. Used by the WMI ping class.
gem 'win32ole', '>= 1.8.8' if Gem.win_platform?

gem 'cap2', '>= 0.2.2' if RUBY_PLATFORM =~ /linux/i

# byebug's C extension does not build on JRuby.
gem 'pry-byebug', '>= 0' unless RUBY_ENGINE == 'jruby'

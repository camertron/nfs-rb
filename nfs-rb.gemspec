$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'nfs/version'

Gem::Specification.new do |s|
  s.name     = 'nfs-rb'
  s.version  = ::NFS::VERSION
  s.authors  = ['Cameron Dutro', 'Brian Ollenberger']
  s.email    = ['camertron@gmail.com']
  s.homepage = 'http://github.com/camertron/nfs'
  s.description = s.summary = 'An NFS v2 server implemented in pure Ruby.'
  s.platform = Gem::Platform::RUBY
  s.require_path = 'lib'

  s.executables << 'nfs-rb'

  s.files = Dir['{lib,spec}/**/*', 'Gemfile', 'LICENSE', 'CHANGELOG.md', 'README.md', 'Rakefile', 'nfs-rb.gemspec']
end

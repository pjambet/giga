require_relative "lib/giga/version"

Gem::Specification.new do |s|
  s.name        = "giga"
  s.version     = Giga::VERSION
  s.executables << "giga"
  s.summary     = "A console text editor, pretty much copied from antirez/kilo"
  s.description = "A console text editor, built pretty much from scratch"
  s.authors     = ["Pierre Jambet"]
  s.email       = "hello@pjam.me"
  s.files       = Dir.glob('{bin,lib}/**/*') + %w(LICENSE README.md)
  s.homepage    =
    "https://rubygems.org/gems/giga"
  s.license       = "MIT"
  s.add_runtime_dependency "ruby-termios", '~> 1.1.0'
  s.add_development_dependency 'mocha', '~> 1.11.2'
  # s.add_development_dependency 'timecop', '~> 0.9.1'
end

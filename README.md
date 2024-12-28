[![Gem Version](https://badge.fury.io/rb/giga.svg)](https://badge.fury.io/rb/giga)

# Giga the text editor

How to start locally:

```ruby
ruby -e "require 'pathname'; \$LOAD_PATH.unshift(Pathname.new(File.expand_path(File.dirname(__FILE__))).join('lib')); require_relative './lib/giga'; height, width = IO.console.winsize; Giga::Editor.new(width: width, height: height).start" 2> error
```
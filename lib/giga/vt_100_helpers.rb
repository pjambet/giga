# frozen_string_literal: true

module Giga
  module VT100Helpers
    def self.foreground_color(color)
      "\x1b[#{ color }m"
    end

    def self.coordinates(x, y)
      "\x1b[#{ y };#{ x }H"
    end
  end
end

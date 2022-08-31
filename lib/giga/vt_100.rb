# frozen_string_literal: true

require "giga/vt_100_helpers"

module Giga
  module VT100
    HIDE = "\x1b[?25l"
    SHOW = "\x1b[?25h"
    HOME = "\x1b[H"
    CLEAR = "\x1b[0K"
    DEFAULT_FOREGROUND_COLOR = VT100Helpers.foreground_color(39)
  end
end

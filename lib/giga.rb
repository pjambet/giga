# frozen_string_literal: true

require "giga/vt_100"
require "io/console"
require "debug"

module Giga
  class Editor
    ESC = 27
    CTRL = ""
    CTRL_Q = 2
    CTRL_S = 19
    CTRL_A = 1
    CTRL_E = 5
    CTRL_N = 14
    CTRL_P = 16
    ENTER = 13
    BACKSPACE = 127
    PRINTABLE_ASCII_RANGE = 32..126
    UP = "A"
    DOWN = "B"
    RIGHT = "C"
    LEFT = "D"
    HOME = "H"
    END_ = "F"

    def initialize(width:, height:, stdin: STDIN, stdout: STDOUT, stderr: STDERR)
      @in = stdin
      @out = stdout
      @err = stderr
      @width = width
      @height = height
      @current = nil
      @text_content = nil
      @x, @y = nil
    end

    def start
      @text_content = [String.new]
      @x = 1
      @y = 1

      raw_mode do
        loop do
          refresh
          char = @in.readpartial(1)
          process_keypress(char)
        end
      end
    end

    private

    def refresh
      append_buffer = String.new
      append_buffer << VT100::HIDE
      append_buffer << VT100::HOME

      @height.times do |row_index|
        if row_index >= @text_content.count
          append_buffer << "~#{ VT100::CLEAR }\r\n"
          next
        end

        row = @text_content[row_index] || String.new
        append_buffer << row
        # https://notes.burke.libbey.me/ansi-escape-codes/
        # https://en.wikipedia.org/wiki/ANSI_escape_code
        append_buffer << VT100::DEFAULT_FOREGROUND_COLOR
        append_buffer << VT100::CLEAR
        append_buffer << "\r\n"
      end
      append_buffer.strip!
      append_buffer << VT100::HOME
      append_buffer << VT100Helpers.coordinates(@x, @y)
      append_buffer << VT100::SHOW
      stderr_log("'#{ append_buffer }'".inspect)
      stderr_log("Cursor postition: x: #{ @x }, y: #{ @y }: #{ @y };#{ @x }H")

      @out.write(append_buffer)
    end

    def current_row
      @text_content[@y - 1]
    end

    def stderr_log(message)
      return if @err.tty? # true when not redirecting to a file, a little janky but works for what I want

      @err.puts(message)
    end

    def raw_mode(&block)
      if @out.tty?
        IO.console.raw(&block)
      else
        block.call
      end
    end

    def extract_dimensions
      return unless @out.tty?

      @height, @width = IO.console.winsize
    end

    def process_keypress(character)
      if character.ord == CTRL_Q
        clear_screen!
        exit(0)
      elsif character.ord == ENTER
        carry = if current_row && current_row.length > (@x - 1)
                  current_row.slice!((@x - 1)..-1)
                else
                  String.new
                end
        new_line_index = if @y - 1 == @text_content.length # We're on a new line at the end
                           @y - 1
                         else
                           @y
                         end
        @text_content.insert(new_line_index, carry)
        @x = 1
        @y += 1
      elsif character.ord == BACKSPACE
        return if @x == 1 && @y == 1

        if @x == 1
          if current_row.nil? || current_row.empty?
            @text_content.delete_at(@y - 1)
            @y -= 1
            @x = current_row.length + 1
          else
            previous_row = @text_content[@y - 2]
            @x = previous_row.length + 1
            @text_content[@y - 2] = previous_row + current_row
            @text_content.delete_at(@y - 1)
            @y -= 1
          end
        else
          deletion_index = @x - 2
          current_row.slice!(deletion_index)
          @x -= 1
        end
      elsif character.ord == CTRL_N
        down!
      elsif character.ord == CTRL_P
        up!
      elsif character.ord == CTRL_A
        beginning_of_line!
      elsif character.ord == CTRL_E
        end_of_line!
      elsif character.ord == ESC
        second_char = @in.read_nonblock(1, exception: false)
        return if second_char == :wait_readable

        third_char = @in.read_nonblock(1, exception: false)
        return if third_char == :wait_readable

        if second_char == "["
          case third_char
          when UP
            up!
          when DOWN
            down!
          when RIGHT
            if current_row && @x > current_row.length
              if @y <= @text_content.length + 1
                @x = 1
                @y += 1
              end
            elsif current_row
              @x += 1
            end
          when LEFT
            if @x == 1
              if @y > 1
                @y -= 1
                @x = current_row.length + 1
              end
            else
              @x -= 1
            end
          when HOME then "H" # Home
          when END_ then "F" # End
          end
        end
      elsif PRINTABLE_ASCII_RANGE.cover?(character.ord)
        @text_content << String.new if current_row.nil?
        current_row.insert(@x - 1, character)
        @x += 1
      else
        stderr_log("Ignored char: #{ character.ord }")
      end
    end

    def up!
      @y -= 1 unless @y == 1
      return unless current_row && @x > current_row.length + 1

      @x = current_row.length + 1
    end

    def down!
      @x = 1 if @y == @text_content.length
      @y += 1 unless @y == @text_content.length + 1
      return unless current_row && @x > current_row.length + 1

      @x = current_row.length + 1
    end

    def beginning_of_line!
      @x = 1
    end

    def end_of_line!
      @x = current_row.length + 1
    end

    def clear_screen!
      clear = ([VT100::HOME] + @height.times.map do
        "#{ VT100::CLEAR }\r\n"
      end + [VT100::HOME]).join
      stderr_log(clear.inspect)
      @out.write(clear)
    end
  end
end

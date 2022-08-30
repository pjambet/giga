# frozen_string_literal: true

require 'termios'
require 'io/console'
require 'stringio'
require 'debug'

module Giga
  class Editor

    ESC = 27
    CTRL = ""
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
      @in, @out, @err = stdin, stdout, stderr
      @width, @height = width, height
      @current = nil
      @text_content = nil
      @x, @y = nil
    end

    def start
      enable_raw_mode

      @text_content = [String.new]
      @x, @y = 1, 1

      loop do
        refresh
        char = @in.readpartial(1)
        process_keypress(char)
      end
    end

    private

    def refresh
      append_buffer = String.new
      append_buffer << "\x1b[?25l" # Hide cursor
      append_buffer << "\x1b[H" # Go home

      @height.times do |row_index|
        if row_index >= @text_content.count
          append_buffer << "~\x1b[0K\r\n" # ~ and clear line
          next
        end

        row = @text_content[row_index] || ""
        append_buffer << row
        # https://notes.burke.libbey.me/ansi-escape-codes/
        # https://en.wikipedia.org/wiki/ANSI_escape_code
        append_buffer << "\x1b[39m" # Default foregroung color
        append_buffer << "\x1b[0K" # Erase the rest of the line
        append_buffer << "\r\n"
      end
      append_buffer.strip!
      append_buffer << "\x1b[H" # Go home
      append_buffer << "\x1b[#{@y};#{@x}H"
      append_buffer << "\x1b[?25h" # Show cursor
      stderr_log("'#{append_buffer}'".inspect)
      stderr_log("Cursor postition: x: #{@x}, y: #{@y}: #{@y};#{@x}H")

      if @out.is_a?(StringIO)
        @out.rewind
        @out.truncate(0)
      end
      @out.write(append_buffer)
    end

    def current_row
      @text_content[@y - 1]
    end

    def stderr_log(message)
      unless @err.tty? # true when not redirecting to a file, a little janky but works for what I want
        @err.puts(message)
      end
    end

    def enable_raw_mode
      IO.console.raw! if @out.tty?
    end

    def extract_dimensions
      if @out.tty?
        @height, @width = IO.console.winsize
      end
    end

    def process_keypress(character)
      if character == "q"
        exit(0)
      end

      if character.ord == ENTER
        if current_row && current_row.length > (@x - 1)
          carry = current_row[(@x - 1)..-1]
          current_row.slice!((@x - 1)..-1)
        else
          carry = ""
        end
        if @y - 1 == @text_content.length # We're on a new line at the end
          new_line_index = @y - 1
        else
          new_line_index = @y
        end
        @text_content.insert(new_line_index, carry)
        @x = 1
        @y += 1
      elsif character.ord == BACKSPACE
        return if @x == 1 && @y == 1

        if @x == 1
          if current_row.nil?
            @text_content.delete_at(@y - 1)
            @y -= 1
            @x = current_row.length + 1
          elsif current_row.empty?
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
      elsif character.ord == ESC
        second_char = @in.read_nonblock(1, exception: false)
        return if second_char == :wait_readable

        third_char = @in.read_nonblock(1, exception: false)
        return if third_char == :wait_readable

        if second_char == "["
          case third_char
          when UP
            @y -= 1 unless @y == 1
            if current_row && @x > current_row.length + 1
              @x = current_row.length + 1
            end
          when DOWN
            if @y == @text_content.length
              @x = 1
            end
            @y += 1 unless @y == @text_content.length + 1
            if current_row && @x > current_row.length + 1
              @x = current_row.length + 1
            end
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
        if current_row.nil?
          @text_content << ""
        end
        current_row.insert(@x - 1, character)
        @x += 1
      else
        stderr_log("Ignored char: #{character.ord}")
      end
    end
  end
end

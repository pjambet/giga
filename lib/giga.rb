require 'termios'
require 'io/console'
require 'stringio'
require 'debug'

module Giga
  class Editor
    def initialize(width:, height:, stdin: STDIN, stdout: STDOUT, stderr: STDERR)
      @in, @out, @err = stdin, stdout, stderr
      @width, @height = width, height
      @current = nil
      @text_content = nil
      @cursor_position = nil
    end

    def refresh
      append_buffer = ""
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
      x, y = @cursor_position
      append_buffer << "\x1b[#{y};#{x}H"
      append_buffer << "\x1b[?25h" # Show cursor
      stderr_log("'#{append_buffer}'".inspect)
      stderr_log("Cursor postition: x: #{@cursor_position[0]}, y: #{@cursor_position[1]}: #{y};#{x}H")

      if @out.is_a?(StringIO)
        @out.rewind
        @out.truncate(0)
      end
      @out.write(append_buffer)
    end

    def current_row
      @text_content[@cursor_position[1] - 1]
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

    def start
      enable_raw_mode

      @text_content = [""]
      @cursor_position = [1, 1]

      loop do
        refresh
        c = @in.readpartial(1)
        if c == "q"
          exit(0)
        end

        if c.ord == 13 # enter
          if current_row && current_row.length > (@cursor_position[0] - 1)
            carry = current_row[(@cursor_position[0] - 1)..-1]
            current_row.slice!((@cursor_position[0] - 1)..-1)
          else
            carry = ""
          end
          if @cursor_position[1] - 1 == @text_content.length # We're on a new line at the end
            new_line_index = @cursor_position[1] - 1
          else
            new_line_index = @cursor_position[1]
          end
          @text_content.insert(new_line_index, carry)
          @cursor_position[0] = 1
          @cursor_position[1] += 1
        elsif c.ord == 127 # backspace
          next if @cursor_position[0] == 1 && @cursor_position[1] == 1

          if @cursor_position[0] == 1
            if current_row.nil?
              @text_content.delete_at(@cursor_position[1] - 1)
              @cursor_position[1] -= 1
              @cursor_position[0] = current_row.length + 1
            elsif current_row.empty?
              @text_content.delete_at(@cursor_position[1] - 1)
              @cursor_position[1] -= 1
              @cursor_position[0] = current_row.length + 1
            else
              previous_row = @text_content[@cursor_position[1] - 2]
              @cursor_position[0] = previous_row.length + 1
              @text_content[@cursor_position[1] - 2] = previous_row + current_row
              @text_content.delete_at(@cursor_position[1] - 1)
              @cursor_position[1] -= 1
            end
          else
            deletion_index = @cursor_position[0] - 2
            current_row.slice!(deletion_index)
            @cursor_position[0] -= 1
          end
        elsif c.ord == 27 # ESC
          second_char = @in.read_nonblock(1, exception: false)
          next if second_char == :wait_readable

          third_char = @in.read_nonblock(1, exception: false)
          next if third_char == :wait_readable

          if second_char == "["
            case third_char
            when "A" # Up
              @cursor_position[1] -= 1 unless @cursor_position[1] == 1
              if current_row && @cursor_position[0] > current_row.length + 1
                @cursor_position[0] = current_row.length + 1
              end
            when "B" # Down
              if @cursor_position[1] == @text_content.length
                @cursor_position[0] = 1
              end
              @cursor_position[1] += 1 unless @cursor_position[1] == @text_content.length + 1
              if current_row && @cursor_position[0] > current_row.length + 1
                @cursor_position[0] = current_row.length + 1
              end
            when "C" # Right
              if current_row && @cursor_position[0] > current_row.length
                if @cursor_position[1] <= @text_content.length + 1
                  @cursor_position[0] = 1
                  @cursor_position[1] += 1
                end
              elsif current_row
                @cursor_position[0] += 1
              end
            when "D" # Left
              if @cursor_position[0] == 1
                if @cursor_position[1] > 1
                  @cursor_position[1] -= 1
                  @cursor_position[0] = current_row.length + 1
                end
              else
                @cursor_position[0] -= 1
              end
            when "H" then "H" # Home
            when "F" then "F" # End
            end
          end
        elsif c.ord >= 32 && c.ord <= 126
          if current_row.nil?
            @text_content << ""
          end
          current_row.insert(@cursor_position[0] - 1, c)
          @cursor_position[0] += 1
        else
          stderr_log("Ignored char: #{c.ord}")
        end
      end
    end
  end
end

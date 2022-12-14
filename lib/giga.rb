require 'termios'

module Giga
  class Editor
    def initialize
    end

    def refresh
      append_buffer = ""
      append_buffer << "\x1b[?25l" # Hide cursor
      append_buffer << "\x1b[H"
      # stderr_log @text_content
      @height.times do |row_index|

        if row_index >= @text_content.count
          append_buffer << "~\x1b[0K\r\n"
          # stderr_log("Row index: #{row_index}")
          # stderr_log("Line count: #{@text_content.count}")
          next
        end

        row = @text_content[row_index] || ""
        # stderr_log "'#{row}'"
        append_buffer << row
        # https://notes.burke.libbey.me/ansi-escape-codes/
        # https://en.wikipedia.org/wiki/ANSI_escape_code
        append_buffer << "\x1b[39m" # Default foregroung color
        append_buffer << "\x1b[0K" # Erase the rest of the line
        append_buffer << "\r\n"
      end
      append_buffer.strip!
      append_buffer << "\x1b[H"
      x, y = @cursor_position
      # x += 1 if x > 0
      append_buffer << "\x1b[#{y};#{x}H"
      # append_buffer << "\x1b[;1H"
      append_buffer << "\x1b[?25h" # Show cursor
      stderr_log("'#{append_buffer}'".inspect)
      stderr_log("Cursor postition: x: #{@cursor_position[0]}, y: #{@cursor_position[1]}: #{y};#{x}H")
      STDOUT.write(append_buffer)
    end

    def current_row
      @text_content[@cursor_position[1] - 1]
    end

    def stderr_log(message)
      unless STDERR.tty? # true when not redirecting to a file, a little janky but works for what I want
        STDERR.puts(message)
      end
    end

    def start
      s = [0, 0, 0, 0].pack("S_S_S_S_")
      STDOUT.ioctl(Termios::TIOCGWINSZ, s)

      @height, @WIDTH, _, _ = s.unpack("S_S_S_S_")

      # Raw mode
      current = Termios.tcgetattr(STDIN)
      t = current.dup
      t.c_iflag &= ~(Termios::BRKINT | Termios::ICRNL | Termios::INPCK | Termios::ISTRIP | Termios::IXON)
      t.c_oflag &= ~(Termios::OPOST)
      t.c_cflag |= (Termios::CS8)
      t.c_lflag &= ~(Termios::ECHO | Termios::ICANON | Termios::IEXTEN | Termios::ISIG)
      t.c_cc[Termios::VMIN] = 1 # Setting 0 as in Kilo raises EOF errors
      Termios.tcsetattr(STDIN, Termios::TCSANOW, t)

      trap("INT") {
        Termios.tcsetattr(STDIN, Termios::TCSANOW, current)
        exit(0)
      }

      @text_content = [""]
      @cursor_position = [1, 1]

      loop do
        refresh
        c = STDIN.readpartial(1)
        if c == "q"
          Process.kill("INT", Process.pid)
        end
        # stderr_log("ord: #{c.ord}")
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
          second_char = STDIN.read_nonblock(1, exception: false)
          next if second_char == :wait_readable

          third_char = STDIN.read_nonblock(1, exception: false)
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
              # stderr_log("Current row: #{current_row}\n")
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
          # @text_content.last << third_char
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

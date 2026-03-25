# frozen_string_literal: true

require "test_helper"
require "debug"

describe Giga do
  before do
    @width = 10
    @height = 12
  end

  it "runs" do
    read_in, write_in = IO.pipe
    read_out, write_out = IO.pipe
    stderr = StringIO.new

    if fork
      # parent
      write_out.close
      read_in.close
      write_in.write("a")
      write_in.write("b")
      write_in.write("\x1B[D") # Mimick left arrow: Esc [ D
      write_in.write("\x1B[C") # Mimick right arrow: Esc [ C
      write_in.write("\x1B[C") # Mimick right arrow: Esc [ C
      write_in.write("\x1B[C") # Mimick right arrow: Esc [ C
      write_in.close
      Process.wait

      expected_content = [
        screen_content("", 1, 1),
        screen_content("a", 2, 1),
        screen_content("ab", 3, 1),
        screen_content("ab", 2, 1),
        screen_content("ab", 3, 1),
        screen_content("ab", 1, 2),
        screen_content("ab", 1, 2),
      ].join

      screen_content = read_out.read
      assert_equal expected_content, screen_content
    else
      # child
      write_in.close
      read_out.close
      begin
        Giga::Editor.new(width: @width, height: @height, stdin: read_in, stdout: write_out, stderr:).start
      rescue EOFError => _e
        read_in.close
        write_out.close
        exit(0)
      end
    end
  end

  it "doesn't crash when calling end_of_line! on a new line at the end of buffer" do
    read_in, write_in = IO.pipe
    read_out, write_out = IO.pipe
    stderr = StringIO.new

    if fork
      # parent
      write_out.close
      read_in.close
      write_in.write("\x0E") # CTRL_N (Down) - should move to line 2 (virtual)
      write_in.write("\x05") # CTRL_E (End of line) - trigger crash
      write_in.close
      _, status = Process.wait2
      assert_equal 0, status.exitstatus, "Editor crashed with status #{status.exitstatus}"
    else
      # child
      write_in.close
      read_out.close
      begin
        # Initialize with 1 line, navigate to line 2
        editor = Giga::Editor.new(width: @width, height: @height, stdin: read_in, stdout: write_out, stderr:)
        editor.start
      rescue EOFError
        exit(0)
      rescue => e
        # Log error so we can see it in failure
        File.open("test_crash.log", "w") { |f| f.write("#{e.class}: #{e.message}\n#{e.backtrace.join("\n")}") }
        exit(1)
      end
    end
  end

  def screen_content(content, x, y)
    parts = ["\x1b[?25l\x1b[H#{ content }\x1b[39m\x1b[0K\r\n"]
    (@height - 2).times do
      parts << "~\x1b[0K\r\n"
    end
    parts << "~\x1b[0K\x1b[H\x1b[#{ y };#{ x }H\x1b[?25h"
    parts.join("")
  end
end

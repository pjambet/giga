require "test_helper"
require "debug"

# class FakeStdIn
#   def initialize
#     @io = StringIO.new
#   end

#   def tty?
#     false
#   end

#   def readpartial(size)
#   end
# end

describe Giga do
  it "runs" do
    stdin, stdout, stderr = StringIO.new, StringIO.new, StringIO.new
    r, w = IO.pipe
    # r2, w2 = IO.pipe
    # puts stdout.object_id
    # puts stderr.object_id
    # sleep 20

    if fork
      w.close

      begin
        editor = Giga::Editor.new(r, stdout, stderr)
        editor.start
      rescue EOFError => e
        puts "reached eof"
      end

      Process.wait

      # binding.break
      stdout.rewind
      screen = read_screen(stdout)
      assert_equal screen_content("abc"), screen
    else
      r.close

      w.write("abc")
      # w.write("b")
      # w.write("c")
    end
  end

  def read_screen(io)
    10.times.map {
      io.gets
    }.join("")
  end

  def screen_content(content)
    parts = ["\x1b[?25l\x1b[H#{content}\x1b[39m\x1b[0K\r\n"]
    # parts << ""
    8.times do
      parts << "~\x1b[0K\r\n"
    end
    parts << "~\x1b[0K\x1b[H\x1b[1;#{content.length + 1}H\x1b[?25h"
    parts.join("")
  end
end
require 'io/console'
require 'open3'

ERASE_ENTIRE = 2

CTRL_C = 3
ENTER = 13
BACKSPACE = 127

CONSOLE_BUFFER_SIZE = 4096
PROMPT_BUFFER_SIZE = 4096

def with_raw_mode
  initial_console_mode = STDIN.console_mode
  raw_console_mode = initial_console_mode.clone
  raw_console_mode.raw!
  STDIN.console_mode = raw_console_mode
  yield IO.console
ensure
  IO.console.erase_screen(ERASE_ENTIRE)
  STDIN.console_mode = initial_console_mode
end

class Neproto
  class << self
    def claim
      with_raw_mode do |console|
        yield new(console)
      end
    end
  end

  def initialize(console)
    @console = console
    @pending_command_line = ""
    @pending_prompt = ""
  end

  def run
    console.erase_screen(ERASE_ENTIRE)

    prompt_stdin, prompt_stdout, prompt_stderr, _prompt_wait = Open3.popen3('./prompt') 
    prompt_stdin.close

    loop do
      ready_ios, * = IO.select([prompt_stdout, console])
      if ready_ios.include?(console)
        new_read = console.read_nonblock(CONSOLE_BUFFER_SIZE)
        new_read.chars.each(&method(:process_typed_char))
      end

      if ready_ios.include?(prompt_stdout)
        @pending_prompt += prompt_stdout.read_nonblock(PROMPT_BUFFER_SIZE)
        lines = pending_prompt.lines
        @pending_prompt = lines.last
        if lines.size >= 2
          set_prompt(lines[-2])
        end
      end
    rescue IO::WaitReadable
      # Just retry -- only technically possible in exceptional cases
      # where the Kernel lies and a nonblocking read fails after select.
      STDERR.puts "Console lied about select :/"
    end
  end

  def process_command(command)
    exit if command == 'quit'
    console.write("Got command: #{command.inspect}\r\n")
  end

  def process_typed_char(char)
    case char.ord
    when CTRL_C
      exit
    when BACKSPACE
      console.cursor_left(1)
      console.write(' ')
      console.cursor_left(1)
    else
      console.write(char)
    end
  end

  def set_prompt(prompt)
    # console.write("Set prompt: #{prompt}\r\n")
  end

  private

  attr_reader :console, :pending_command_line, :pending_prompt
end

Neproto.claim do |instance|
  instance.run
end

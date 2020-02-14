require 'io/console'
require 'open3'

ERASE_ENTIRE = 2

def with_raw_mode
  initial_console_mode = STDIN.console_mode
  raw_console_mode = initial_console_mode.clone
  raw_console_mode.raw!
  STDIN.console_mode = raw_console_mode
  print("\u001B[?25l")
  yield IO.console
ensure
  print("\u001B[?25h")
  IO.console.erase_screen(ERASE_ENTIRE)
  STDIN.console_mode = initial_console_mode
end

with_raw_mode do |console|
  console.erase_screen(ERASE_ENTIRE)

  prompt_stdin, prompt_stdout, prompt_stderr, prompt_wait = Open3.popen3('./prompt') 
  raise 'Cannot close prmopt stdin' unless prompt_stdin.close

  prompt_stdout.readlines.each do |prompt|
    console.erase_line(ERASE_ENTIRE)
    console.write("\r")
    console.write(prompt)
  end
end

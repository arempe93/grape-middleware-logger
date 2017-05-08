module Colors
  extend self

  ESCAPE = '\e['
  RESET = '0m'
  CODES = {
    red: '31m',
    green: '32m',
    yellow: '33m',
    blue: '34m',
    magenta: '35m',
    cyan: '36m'
  }

  CODES.each do |color, code|
    define_method(color) do |string|
      "#{ESCAPE}#{code}#{string}#{ESCAPE}#{RESET}"
    end
  end
end

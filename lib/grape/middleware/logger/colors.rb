module Colors
  extend self

  ESCAPE = "\e["
  RESET = '0m'
  CODES = {
    black: '30m',
    red: '31m',
    green: '32m',
    yellow: '33m',
    blue: '34m',
    magenta: '35m',
    cyan: '36m'
  }

  CODES.each do |color, code|
    define_method(color) do |string, bold: false|
      attributes = code
      attributes << ';1' if bold
      "#{ESCAPE}#{attributes}#{string}#{ESCAPE}#{RESET}"
    end
  end
end

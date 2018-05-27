module Supervisor
  module CommandParser

    def self.parse(command)
      on_word = false
      iterator = command.each_char
      buf = IO::Memory.new
      words = [] of String
      loop do
        c = next_char(iterator)
        case c
        when '\''
          on_word = true
          read_quoted_word(iterator, buf)
        when '"'
          on_word = true
          read_double_quoted_word(iterator, buf)
        when ' '
          if on_word
            words << buf.to_s
            buf.clear
            on_word = false
          end
        when nil
          if on_word
            words << buf.to_s
            buf.clear
          end
          break
        else
          on_word = true
          buf << c
        end
      end
      words
      bin = words[0]
      args = words[1..-1]
      {bin, args}
    end

    private def self.next_char(iterator)
      char = iterator.next
      case char
      when '\n'
        raise Exception.new("contains newline char")
      when Char
        char
      else
        nil
      end
    end

    private def self.read_quoted_word(iterator, buf)
      loop do
        c = next_char(iterator)
        case c
        when '\''
          return
        when nil
          raise Exception.new("expected '  but EOL reached")
        else
          buf << c
        end
      end
    end

    private def self.read_double_quoted_word(iterator, buf)
      loop do
        c = next_char(iterator)
        case c
        when '"'
          break
        when nil
          raise Exception.new("expected \" but EOL reached")
        when '\\'
          c1 = next_char(iterator)
          case c1
          when '"'
            buf << c1
          else
            buf << c
            buf << c1
          end
        else
          buf << c
        end
      end
    end
  end
end

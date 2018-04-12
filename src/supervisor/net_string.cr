module Supervisor
  module NetString

    def self.read(io)
      num = String.build(3) do |str|
        loop do
          byte = io.read_byte
          return nil if ! byte
          chr = byte.chr
          if chr >= '0' && chr <= '9'
            str << chr
          elsif chr == ':'
            break
          else
            raise MalformedNetString.new("non numeric length specified")
          end
        end
      end
      raise MalformedNetString.new("length not specified") if num.size == 0
      len = num.to_i
      data = io.read_string(len)
      byte = io.read_byte
      chr = byte ? byte.chr : '0'
      raise MalformedNetString.new("expected trailing comma got #{chr}") if chr != ','
      data
    end

    def self.build(data : String)
      len = data.bytesize
      "#{len}:#{data},"
    end
  end

  class MalformedNetString < Exception
  end
end


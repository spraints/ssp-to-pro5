require "yaml"

def main(*files)
  files.each do |file|
    begin
      parsed = parse(file)
      if ENV["RM_GOOD"] == "y" && parsed.is_a?(Array) && file.start_with?("_problems/")
        File.unlink(file)
      end
      puts(YAML.dump(file => parsed))
    rescue => e
      puts "#{file}: #{e}"
      puts e.backtrace.take(5)
    end
  end
end

def parse(path)
  File.open(path, "rb") do |f|
    parse_io(f)
  end
end

FieldNames = {
   1 => "title",
   2 => "artist",
   3 => "copyright",
   5 => "ccli#",
  29 => "keyword",
  31 => "typical order",
  37 => "song part",
  38 => "version",
}

def parse_io(io)
  consumed = []
  parsed = []
  begin
    r = ReadHelper.new(io)
    r = LoggingReader.new(r, consumed)
    loop do
      type, len, flags = r.tag
      parsed.push(data = [])
      data.push FieldNames[type] || type
      if flags == 6 || flags == 2
        # Just a normal string value in this field.
        data.push(value = r.b_string)
        len = len - value.bytesize - 2
      elsif flags == 20
        # A somewhat simple string field, though it has some extra padding.
        data.push(value = r.b_3_string)
        len = len - value.bytesize - 5
      elsif len == 1 && flags == 9
        # nothing
      elsif len == 5 && flags == 18
        # yes! we made it to the end!
        return parsed if r.int == :eof
      else
        if type == 34
          # This seems to be a field with a bunch of binary data / flags / background settings, etc.
          io.pos -= 8
        end
        break
      end
      if((type == 39 && data.size == 2) || type == 40)
        # another variant of the end (probably), this time with the last field of the file.
        return (parsed + [io.read.inspect])
      end
      if type == 37
        # Verses have a name plus the content of the verse.
        data.push r.byte
        data.push r.b_string
      end
    end
    # If we stopped reading, put a snippet of it in the output so I can try to figure out what's next.
    consumed.push(rest = [])
    rest << io.pos
    rest << io.size
    rest << io.read(100).inspect
  rescue => e
    consumed.push([e.class.name, e.message] + e.backtrace)
  end
  if ENV["DBG"] != "y"
    consumed = consumed.reverse.take(10).reverse
  end
  {:parsed => parsed, :consumed => consumed}
end

# Intercept calls to the real Reader so that I can see what things have come out of the IO.
class LoggingReader
  def initialize(reader, log)
    @reader = reader
    @log = log
  end

  def method_missing(m, *a)
    @reader.send(m, *a).tap do |result|
      @log.push m => result
    end
  end

  def respond_to?(m)
    @reader.respond_to?(m) || super
  end
end

# Read typed data from the IO.
class ReadHelper
  def initialize(io)
    @io = io
  end

  attr_reader :io

  def string(len)
    guarded_read(len).force_encoding("UTF-8")
  end

  def tag
    [byte, int, int]
  end

  def b_string
    len = byte
    string(len)
  end

  def b_3_string
    len = byte
    zeroes = [byte, byte, byte]
    str = string(len)
    if zeroes.any? { |n| n != 0 }
      zeroes + [str]
    else
      str
    end
  end

  def int
    if _bytes_left == 3
      :eof
    else
      guarded_read(4).unpack("N").first
    end
  end

  def byte
    guarded_read(1).unpack("C").first
  end

  def _bytes_left
    io.size - io.pos
  end

  def guarded_read(len)
    if _bytes_left >= len
      io.read(len)
    else
      n = _bytes_left
      s = io.read
      raise "Tried to read #{len}, but only have #{n} bytes (#{s.inspect}) left"
    end
  end
end

main(*ARGV)

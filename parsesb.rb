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
      if type == 36 && flags == 2 && flags == 2
        data.push r.byte
      elsif flags == 6 || flags == 2 || (flags & 0x00FF) == 6
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
      elsif type == 34
        # Not sure what this is.
        #data << len
        #data << flags
        # len = 46 -> bytes left = 380
        # len = 152 -> bytes left = 1461
        # len = 154 -> bytes left = 1463
        # len = 177 -> bytes left = 9153, plux XML.
        # len = 177 -> bytes left = 9166, plux XML.
        # len = 180 -> bytes left = 9169, plux XML.
        # len = 201 -> bytes left = 16358, including what looks like XML.
        #data << "pos: #{io.pos}"
        return parsed # We don't need anything after this mark.
      else
        if type == 0
          io.pos -= 20
        end
        break
      end
      if((type == 39 && (data.size == 2 || (len == 5 && flags == 18))) || type == 40)
        # another variant of the end (probably), this time with the last field of the file.
        return (parsed + [io.read.inspect])
      end
      if type == 37
        # Verses have a name (read above) plus the content of the verse.
        data.push(more_flags = r.byte)
        if more_flags == 6
          if flags == 0x01000006
            data.push r.b_3_string
          else
            data.push r.b_string
          end
        elsif more_flags == 20 || more_flags == 12
          data.push r.b_3_string
        elsif more_flags == 18
          data.push r.int
        else
          break
        end
      end
    end
    # If we stopped reading, put a snippet of it in the output so I can try to figure out what's next.
    consumed.push(rest = [])
    rest << io.pos
    rest << io.size
    peek_len = ENV["PEEK"].to_i
    peek_len = 100 if peek_len < 1
    rest << io.read(peek_len).inspect
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
      @log.push m => _format(m, result)
    end
  end

  def respond_to?(m)
    @reader.respond_to?(m) || super
  end

  def _format(m, x)
    return x if x.is_a?(Symbol)
    case m
    when :byte
      "%02x (%d)" % [x, x]
    when :int
      "%08x (%d)" % [x, x]
    when :tag
      [_format(:byte, x[0]), _format(:int, x[1]), _format(:int, x[2])]
    else
      x
    end
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
    len = int_little_endian
    if len > _bytes_left
      io.pos -= 4
      return b_string
    end
    orig_pos = io.pos
    begin
      string(len)
    rescue => e
      io.pos = orig_pos
      raise
    end
  end

  def int
    if _bytes_left == 3
      :eof
    else
      guarded_read(4).unpack("N").first
    end
  end

  def int_little_endian
    guarded_read(4).unpack("V").first
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

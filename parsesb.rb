require "yaml"

def main(*files)
  files.each do |file|
    begin
      parsed = parse(file)
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
        data.push(value = r.b_string)
        len = len - value.bytesize - 2
      elsif flags == 20
        data.push(value = r.b_3_string)
        len = len - value.bytesize - 5
      elsif len == 1 && flags == 9
        # nothing
      elsif len == 5 && flags == 18
        data.push int
      else
        break
      end
      if type == 37
        data.push r.byte
        data.push r.b_string
        #data.push [r.byte, len]
        #data.push io.read(len - 2).inspect
        #data.push r.string(len - 1)
      end
    end
    consumed << io.read(100).inspect
  rescue => e
    consumed.push([e.class.name, e.message] + e.backtrace)
  end
  {:parsed => parsed, :consumed => consumed.reverse.take(10).reverse}
end

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

class ReadHelper
  def initialize(io)
    @io = io
  end

  attr_reader :io

  def string(len)
    io.read(len).force_encoding("UTF-8")
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
    byte ; byte ; byte
    string(len)
  end

  def int
    io.read(4).unpack("N").first
  end

  def byte
    io.read(1).unpack("C").first
  end
end

main(*ARGV)

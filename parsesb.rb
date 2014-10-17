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

def parse_io(io)
  result = {}
  result[:parsed] = consume(io)
  #result[:rest] = io.read
  result
end

FieldNames = {
  38 => "version?",
   1 => "title",
   2 => "copyright",
  36 => "unknown(36)",
}

def consume(io)
  consumed = []
  parsed = {}
  r = ReadHelper.new(io)
  r = LoggingReader.new(r, consumed)
  loop do
    type, len, six = r.tag
    if field = FieldNames[type]
      parsed[field] = r.b_string
    else
      break
    end
  end
  consumed << io.read(100).inspect
  [parsed, consumed.reverse.take(4).reverse]
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
    string(byte)
  end

  def int
    io.read(4).unpack("N").first
  end

  def byte
    io.read(1).unpack("C").first
  end
end

main(*ARGV)

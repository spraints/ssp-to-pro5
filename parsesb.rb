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

def consume(io)
  r = ReadHelper.new(io)
  consumed = []
  consumed.push :signature => (signature = r.byte)
  consumed.push :int => r.int
  consumed.push :int => r.int
  if signature == 38
    new_stuff = []
    new_stuff.push :b_string => (subsig = r.b_string)
    new_stuff.push :byte => r.byte
    new_stuff.push :int => r.int
    new_stuff.push :int => r.int
    consumed.push :new_stuff => new_stuff
  end
  consumed.push :name => r.b_string
  consumed.push :byte => r.byte
  consumed.push :size718 => (size718 = r.int)
  consumed.push :int => r.int
  if signature == 38
    if subsig == "0718"
      consumed.push :int => r.int
      consumed.push :copyright => r.string(size718 - 5).force_encoding("UTF-8")
    elsif subsig == "0707" && size718 > 4
    end
  else
    consumed.push :copyright => r.b_string
  end
  consumed.push io.read(100).inspect
  consumed
end

class ReadHelper
  def initialize(io)
    @io = io
  end

  attr_reader :io

  def string(len)
    io.read(len)
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

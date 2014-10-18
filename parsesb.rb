require "yaml"

def main(*files)
  files.each do |file|
    begin
      parsed = parse(file)
      if parsed.is_a?(Array)
        if ENV["RM_GOOD"] == "y" && file.start_with?("_problems/")
          File.unlink(file)
        end
        song = interpret(parsed)
        pro5 = File.join(File.dirname(file), "#{File.basename(file, ".sbsong")}.pro5")
        puts "#{pro5} will be:"
        render_pro5($stdout, song)
      else
        puts(YAML.dump(file => parsed))
      end
    rescue => e
      puts "#{file}: #{e}"
      puts e.backtrace.take(5)
    end
  end
end

TimeFormat = "%Y-%m-%dT%H:%M:%S"

def render_pro5(io, song)
  io.puts <<HEAD
<?xml version="1.0" encoding="UTF-8"?>
<RVPresentationDocument height="768" width="1024" versionNumber="500" docType="0" creatorCode="1349676880" lastDateUsed="#{Time.now.strftime(TimeFormat)}" usedCount="0" category="Song" resourcesDirectory="" backgroundColor="0 0 0 1" drawingBackgroundColor="0" notes="#{song[:keywords].join(" ")}" artist="#{song["artist"]}" author="#{song["artist"]}" album="" CCLIDisplay="0" CCLIArtistCredits="" CCLISongTitle="#{song["title"]}" CCLIPublisher="#{song["copyright"]}" CCLICopyrightInfo="#{song["copyright"]}" CCLILicenseNumber="#{song["ccli#"]}" chordChartPath="">
    <_-RVProTransitionObject-_transitionObject transitionType="-1" transitionDuration="1" motionEnabled="0" motionDuration="20" motionSpeed="100" />
HEAD
  verse_uuids = Hash.new { |h,k| h[k] = new_uuid }
  render_pro5_verses(io, song, verse_uuids)
  render_pro5_arrangement(io, song, verse_uuids)
  io.puts <<TAIL
</RVPresentationDocument>
TAIL
end

StandardSlides = ["blank slide", "title slide"]
def render_pro5_verses(io, song, verse_uuids)
  io.puts %Q{<groups containerClass="NSMutableArray">}

  song[:parts].each.with_index do |(name, lyrics), i|
    render_pro5_verse(io, name, lyrics, i, verse_uuids[name])
  end
  StandardSlides.each.with_index do |name, i|
    render_pro5_verse(io, name, "", i + song[:parts].size, verse_uuids[name])
  end

  io.puts %Q{</groups>}
end

def render_pro5_verse(io, name, lyrics, i, uuid)
  rtf_data = make_rtf(lyrics)
  io.puts <<VERSE
<RVSlideGrouping name="#{name}" uuid="#{uuid}" color="0 0 1 1" serialization-array-index="#{i}">
  <slides containerClass="NSMutableArray">
    <RVDisplaySlide backgroundColor="0 0 0 1" enabled="1" highlightColor="0 0 0 0" hotKey="" label="" notes="" slideType="1" sort_index="1" UUID="#{new_uuid}" drawingBackgroundColor="0" chordChartPath="" serialization-array-index="0">
      <cues containerClass="NSMutableArray"/>
      <displayElements containerClass="NSMutableArray">
        <RVTextElement displayDelay="0" displayName="Default" locked="0" persistent="0" typeID="0" fromTemplate="1" bezelRadius="0" drawingFill="0" drawingShadow="1" drawingStroke="0" fillColor="0 0 0 0" rotation="0" source="" adjustsHeightToFit="0" verticalAlignment="0" RTFData="#{rtf_data}" revealType="0" serialization-array-index="0">
          <_-RVRect3D-_position x="30" y="30" z="0" width="964" height="708"/>
          <_-D-_serializedShadow containerClass="NSMutableDictionary">
            <NSMutableString serialization-native-value="{2.8284299, -2.8284299}" serialization-dictionary-key="shadowOffset"/>
            <NSNumber serialization-native-value="4" serialization-dictionary-key="shadowBlurRadius"/>
            <NSColor serialization-native-value="0 0 0 1" serialization-dictionary-key="shadowColor"/>
          </_-D-_serializedShadow>
          <stroke containerClass="NSMutableDictionary">
            <NSColor serialization-native-value="0 0 0 0" serialization-dictionary-key="RVShapeElementStrokeColorKey"/>
            <NSNumber serialization-native-value="0" serialization-dictionary-key="RVShapeElementStrokeWidthKey"/>
          </stroke>
        </RVTextElement>
      </displayElements>
      <_-RVProTransitionObject-_transitionObject transitionType="-1" transitionDuration="1" motionEnabled="0" motionDuration="20" motionSpeed="100"/>
    </RVDisplaySlide>
  </slides>
</RVSlideGrouping>
VERSE
end

def make_rtf(lyrics)
  # This is an example of the RTF content of a song I made:
  #    {\rtf1\ansi\ansicpg1252\cocoartf1265\cocoasubrtf210
  #    \cocoascreenfonts1{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
  #    {\colortbl;\red255\green255\blue255;}
  #    \pard\tx560\tx1120\tx1680\tx2240\tx2800\tx3360\tx3920\tx4480\tx5040\tx5600\tx6160\tx6720\pardirnatural\qc
  #
  #    \f0\fs102\fsmilli51200 \cf1 \expnd0\expndtw0\kerning0
  #    \outl0\strokewidth-20 \strokec0 Up above the world so high\
  #    Like a diamond in the sky}
  # This uses stuff from the LyricConverter project:
  rtf = ['{\\rtf1\\ansi\\ansicpg1252\\cocoartf1038\\cocoasubrtf320',
      '{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;}',
      '{\\colortbl;\\red255\\green255\\blue255;}',
      '\\pard\\tx560\\tx1120\\tx1680\\tx2240\\tx2800\\tx3360\\tx3920\\tx4480\\tx5040\\tx5600\\tx6160\\tx6720\\qc\\pardirnatural',
      '',
      "\\f0\\fs96 \\cf1 #{lyrics.gsub(/\r\n/, "\\\n")}}"
  ].join("\n")
  [rtf].pack("m0")
end

def render_pro5_arrangement(io, song, verse_uuids)
  io.puts <<HEAD
<arrangements containerClass="NSMutableArray">
  <RVSongArrangement name="typical" uuid="#{new_uuid}" color="0 0 0 0" serialization-array-index="0">
    <groupIDs containerClass="NSMutableArray">
HEAD
  song[:order].each.with_index do |verse_name, i|
    begin
      verse_uuid = verse_uuids.fetch(verse_name)
      io.puts %Q{<NSMutableString serialization-native-value="#{verse_uuid}" serialization-array-index="#{i}"/>}
    rescue KeyError => e
      puts "[warning] skipping #{verse_name.inspect}: #{e}"
    end
  end
  io.puts <<TAIL
    </groupIDs>
  </RVSongArrangement>
</arrangements>
TAIL
end

require "securerandom"
def new_uuid
  SecureRandom.uuid.upcase
end

def interpret(parsed_song)
  parts = {}
  order = []
  keywords = []
  song = {:parts => parts, :order => order, :keywords => keywords}
  parsed_song.each do |segment|
    next unless segment.is_a?(Array)
    case segment.first
    when FieldNames[37] # song part
      _, part_name, _, content = segment
      if parts.include?(part_name)
        raise "Already have a #{part_name.inspect} in #{song.inspect}!"
      end
      parts[part_name] = content
    when FieldNames[31] # typical order
      _, part_name = segment
      order << part_name
    when FieldNames[29] # keywords
      _, keyword = segment
      keywords << keyword
    when String
      name, value = segment
      song[name] = value
    end
  end
  song
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

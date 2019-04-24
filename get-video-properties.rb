require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'json', '~> 2.2'
  gem 'hashie', '~> 3.6'
end

require 'json'
require 'Hashie'
# include Hashie::Extensions::SymbolizeKeys

filepath = ARGV.first

# "/Volumes/Storage/Videos/TV Shows/Big Bang Theory/Season.4/The Big Bang Theory S04E01 The Robotic Manipulation.mp4"

puts "filepath: #{filepath}"

# query video and get width
# https://stackoverflow.com/questions/3159945/running-command-line-commands-within-ruby-script
# https://stackoverflow.com/questions/684015/how-can-i-get-the-resolution-width-and-height-for-a-video-file-from-a-linux-co

# ffprobe -v quiet -print_format json -show_format -show_streams ~/Movies/big_buck_bunny_720p_5mb.mp4
# ffprobe -v quiet -print_format json -show_format -show_streams "/Volumes/Storage/Videos/TV Shows/Big Bang Theory/Season.4/The Big Bang Theory S04E01 The Robotic Manipulation.mp4"

# ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 input.mp4

def get_video_size(filepath)
  video_properties = %x(ffprobe -v quiet -print_format json -show_format -show_streams "#{filepath}")
  video_properties_hash = Hashie.symbolize_keys(JSON.parse(video_properties))
  # video_properties_hash = Hashie::Mash.new JSON.parse(video_properties)
  # puts "#{video_properties}"
  # puts "#{video_properties_hash.inspect}"

  # puts "#{video_properties_hash[:streams][0].inspect}"
  # puts "#{video_properties_hash[:streams].select { |s|  s[:codec_type] == "video" && s[:codec_name] == "h264" }.inspect}"

  h = video_properties_hash[:streams]
    .select { |s|  s[:codec_type] == "video" }
    .map { |s| {:codec_type => s[:codec_type], :codec_name => s[:codec_name], :codec_long_name => s[:codec_long_name], :height => s[:height], :coded_height => s[:coded_height]}}
  puts "#{filepath} => #{JSON.pretty_generate(h)}"
end


# stuff = %x(ffprobe -v quiet -print_format json -show_format -show_streams "#{filepath}")
# stuffhash = JSON.parse(stuff)
# puts "#{stuff}"
# puts "stuff: #{stuffhash['streams']}"

get_video_size(filepath)
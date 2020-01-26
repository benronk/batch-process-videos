require 'json'
require 'logger'
require 'filesize'
require 'fileutils'
require 'pp'


def get_files (path)
Dir[ File.join(path, '**', '*') ]
    .reject { |f| File.directory? f}
    .select { |f| File.extname(f) == '.ts' }
end

path = '/Volumes/storage/videos/videos'
p "#{path}"
if Dir.exist?(path)
  files = get_files(path)
  puts "Try to move #{files.count} files"
  files.each do |file|
    puts "move this file: #{file}"
    move_to = file.sub('videos/videos', 'videos')
    puts "to this location: #{move_to}"
    FileUtils.mv file, File.dirname(move_to)
    # return
  end
end
require 'json'
require 'Hashie'
require 'logger'
require 'filesize'
require 'fileutils'
require 'pp'

$extensions = []
paths = ['/Volumes/storage/videos/']

paths.each do |path|
  if Dir.exist?(path)
    files = Dir[ File.join(path, '**', '*') ].reject{ |f| File.directory? f}
    files.each do |file|
      # record all of the file types
      if File.file?(file) && !$extensions.include?(File.extname(file))
        $extensions.push(File.extname(file))
      end
    end
  else
    puts "path is not a dir: #{path}"
  end
end

puts "extensions: #{$extensions}"
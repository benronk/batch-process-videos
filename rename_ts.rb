require 'json'
require 'logger'
require 'filesize'
require 'fileutils'
require 'pp'

$logger = Logger.new('logs/rename-ts.log', 'daily')
@paths = [
  '/Volumes/storage/videos/tv.shows/',
  '/Volumes/storage/videos/sports'
]

def get_files (path)
  Dir[ File.join(path, '**', '*') ]
    .reject { |f| File.directory? f}
    .reject { |f| f.include?('processme.ts') }
    .select { |f| File.extname(f) == '.ts' }
end

@paths.each do |path|
  $logger.info "START path: #{path}"
  if Dir.exist?(path)
    files = get_files(path)
    i = 0
    $logger.info "#{files.count} files to rename"
    # $logger.info "#{files.pretty_inspect}"
    files.each do |file|
      $logger.info "rn this: #{file}"
      new_name = file.sub('.ts', '.processme.ts')
      $logger.info "to this: #{new_name}"
      FileUtils.mv file, new_name
      
      i = i + 1
    end

    puts "#{i} .ts files renamed in #{path}"
  else
    $logger.error "path is not a dir: #{path}"
  end
end
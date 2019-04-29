require 'json'
require 'logger'
require 'filesize'
require 'fileutils'
require 'pp'

@EXCLUDED_DIRS = ['/deal.with.these', '/raw', '/woodworking', '/paw patrol' '/wild.kratts', '/word world']
@PROCESS_FILES_FOLDER = '/processme'
@VIDEO_EXTENSIONS = [".mkv", ".mp4", ".m4v", ".divx", ".mpg"]

@logger = Logger.new('logs/process.log', 'daily')
@total_space_reduction = 0

@paths = ['/Volumes/storage/videos/tv.shows/',
         '/Volumes/storage/videos/movies']

def get_files (path)
  Dir[ File.join(path, '**', '*') ]
    .reject{ |f| File.directory? f}
    .reject{ |f| @EXCLUDED_DIRS.any? { |p| File.dirname(f).downcase.include? p}}
    .select{ |f| File.dirname(f).downcase.include? @PROCESS_FILES_FOLDER}
end

def process_files(files)
  i = files.count
  files.each do |file|
    # Ignore non-video files
    
    if File.file?(file) && @VIDEO_EXTENSIONS.include?(File.extname(file))
      transcode_file(file)
    else
      move_here = File.dirname(file).sub!(@PROCESS_FILES_FOLDER, '')
      @logger.info "skipping: #{file} and moving to #{move_here}"
      FileUtils.mv file, move_here
    end

    i = i - 1
    @logger.info "#{i} files left"
  end
end

def transcode_file(file)
  @logger.info "transcode start: #{File.basename(file)}"
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  transcode_file = file.sub(@PROCESS_FILES_FOLDER, '')
  transcode_folder = File.dirname(transcode_file)
  deleteme_file = transcode_file.sub('videos', 'videos/processed')
  deleteme_folder = File.dirname(deleteme_file)
  
  if !Dir.exist? transcode_folder
    @logger.info "creating: #{transcode_folder}"
    FileUtils.mkdir_p transcode_folder
  end

  # if this file is already a file in the processed folder it's probably incomplete so delete it so we can transcode it again
  if File.exist? transcode_file
    File.delete transcode_file
  end

  %x(transcode-video --no-log --encoder vt_h264 --target small --output "#{transcode_file}" "#{file}")

  if !File.exist? transcode_file
    @logger.info "failed transcode for some reason: #{file}"
    @logger.info "run this command to find out why it failed:: transcode-video -vv --no-log --encoder vt_h264 --target small --output #{transcode_file} #{file}"
  else
    finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @total_space_reduction += Filesize.from(File.size(file).to_s + " b") - Filesize.from(File.size(transcode_file).to_s + " b")
    @logger.info "transcode finished - time: #{((finish - start)/60).ceil} minutes - smaller by: #{(Filesize.from(File.size(file).to_s + " b") - Filesize.from(File.size(transcode_file).to_s + " b")).pretty} - total space reduced: #{@total_space_reduction.pretty}"


    if !Dir.exist? deleteme_folder
      @logger.info "creating: #{deleteme_folder}"
      FileUtils.mkdir_p deleteme_folder
    end

    FileUtils.mv file, deleteme_file
  end
end

#
# start
#

@paths.each do |path|
  @logger.info "START path: #{path}"
  if Dir.exist?(path)
    files = get_files(path)
    @logger.info "#{files.count} files to process"
    @logger.info "#{files.pretty_inspect}"
    process_files files
  else
    @logger.error "path is not a dir: #{path}"
  end
end
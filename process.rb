require 'json'
require 'logger'
require 'filesize'
require 'fileutils'
require 'pp'

@EXCLUDED_DIRS = ['/deal.with.these', '/raw', '/woodworking', '/paw patrol' '/wild.kratts', '/word world']
@PROCESS_FILES_INCLUDING_THIS = ['processme', 'processme720']
@VIDEO_EXTENSIONS = [".mkv", ".mp4", ".m4v", ".divx", ".mpg"]

@logger = Logger.new('logs/process.log', 'daily')
@total_space_reduction = 0

@paths = ['/Users/bronk/dev/batch-process-videos/test_files',
          '/Volumes/storage/videos/tv.shows/',
          '/Volumes/storage/videos/movies']

def get_files (path)
  Dir[ File.join(path, '**', '*') ]
    .reject{ |f| File.directory? f}
    .reject{ |f| @EXCLUDED_DIRS.any? { |p| File.dirname(f).downcase.include? p.downcase}}
    .select{ |f| @PROCESS_FILES_INCLUDING_THIS.any? { |p| File.basename(f).downcase.include? p.downcase}}
end

def process_files(files)
  i = files.count
  files.each do |file|
    # Ignore non-video files
    
    if File.file?(file) && @VIDEO_EXTENSIONS.include?(File.extname(file))
      transcode_file(file)
    else
      @logger.info "skipping #{file} because file extension says it's not a video"
    end

    i = i - 1
    @logger.info "#{i} files left"
  end
end

def transcode_file(file)
  @logger.info "transcode start: #{File.basename(file)}" 

  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  process_tag = @PROCESS_FILES_INCLUDING_THIS.select { |n| File.basename(file).downcase.include? '.'+n.downcase+'.'}

  transcoded_file = file.sub(process_tag, '')
  deleteme_file = transcoded_file.sub('videos', 'videos/processed')
  deleteme_folder = File.dirname(deleteme_file)

  # if this file is already a file in the processed folder it's probably incomplete so delete it so we can transcode it again
  if File.exist? transcoded_file
    File.delete transcoded_file
  end
  
  if process_tag.include? '720'
    # %x(transcode-video --no-log --encoder vt_h264 --720 --target small --output "#{transcoded_file}" "#{file}")
    %x(transcode-video --no-log --720 --target small --output "#{transcoded_file}" "#{file}")
  else
    # %x(transcode-video --no-log --encoder vt_h264 --target small --output "#{transcoded_file}" "#{file}")
    %x(transcode-video --no-log --target small --output "#{transcoded_file}" "#{file}")
  end

  if !File.exist? transcoded_file
    @logger.info "failed transcode for some reason: #{file}"
    @logger.info "run this command to find out why it failed:: transcode-video -vv --no-log --encoder vt_h264 --target small --output #{transcoded_file} #{file}"
  else
    finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @total_space_reduction += Filesize.from(File.size(file).to_s + " b") - Filesize.from(File.size(transcoded_file).to_s + " b")
    @logger.info "transcode finished - time: #{((finish - start)/60).ceil} minutes - smaller by: #{(Filesize.from(File.size(file).to_s + " b") - Filesize.from(File.size(transcoded_file).to_s + " b")).pretty} - total space reduced: #{@total_space_reduction.pretty}"


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
  p "#{path}"
  if Dir.exist?(path)
    files = get_files(path)
    @logger.info "#{files.count} files to process"
    @logger.info "#{files.pretty_inspect}"
    process_files files
  else
    @logger.error "path is not a dir: #{path}"
  end
end
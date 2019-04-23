require 'json'
require 'Hashie'
require 'logger'
require 'filesize'
require 'fileutils'
require 'pp'

$logger = Logger.new('logs/process.log', 'daily')
$excluded_dirs = ['/deal.with.these', '/raw', '/woodworking', '/paw patrol' '/wild.kratts', '/word world']
$PROCESS_FILES_FOLDER = '/processme'

$extensions = []
$total_space_reduction = 0
# paths = ['/Volumes/storage/videos/movies']
paths = ['/Volumes/storage/videos/tv.shows']

def get_files (path)
  Dir[ File.join(path, '**', '*') ]
    .reject{ |f| File.directory? f}
    .reject{ |f| $excluded_dirs.any? { |p| File.dirname(f).downcase.include? p}}
    .select{ |f| File.dirname(f).downcase.include? $PROCESS_FILES_FOLDER}
end

def process_files(files)
  totes = files.count
  files.each do |file|
    # record all of the file types
    if File.file?(file) && !$extensions.include?(File.extname(file))
      $extensions.push(File.extname(file))
    end

    # Ignore non-video files
    # All file extensions in /videos/:  [".mkv", ".mp4", ".jpg", ".srt", ".avi", ".txt", ".m4v", ".part", ".3gp", ".BUP", ".IFO", ".VOB", ".json", ".xml", ".ISO", ".divx", ".rar", ".mpg", ".mp3", ".docx"]
    video_exts = [".mkv", ".mp4", ".m4v", ".divx", ".mpg"]
    if File.file?(file) && video_exts.include?(File.extname(file))
      transcode_file(file)
    else
      move_here = File.dirname(file).sub!($PROCESS_FILES_FOLDER, '')
      $logger.info "skipping: #{file} and moving to #{move_here}"
      FileUtils.mv file, move_here
    end

    totes = totes - 1
    $logger.info "#{totes} files left"
  end
end

def transcode_file(file)
  $logger.info "transcode start: #{File.basename(file)}"
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  transcode_file = file.sub($PROCESS_FILES_FOLDER, '')
  transcode_folder = File.dirname(transcode_file)
  deleteme_file = transcode_file.sub('videos', 'videos/processed')
  deleteme_folder = File.dirname(deleteme_file)

  # $logger.info "transcode_folder: #{transcode_folder}"
  # $logger.info "transcode_file: #{transcode_file}"
  
  if !Dir.exist? transcode_folder
    $logger.info "creating: #{transcode_folder}"
    FileUtils.mkdir_p transcode_folder
  end

  if !Dir.exist? deleteme_folder
    $logger.info "creating: #{deleteme_folder}"
    FileUtils.mkdir_p deleteme_folder
  end

  # if this file is already a file in the processed folder it's probably incomplete so delete it so we can transcode it again
  if File.exist? transcode_file
    File.delete transcode_file
  end

  %x(transcode-video --no-log --encoder vt_h264 --target small --output "#{transcode_file}" "#{file}")

  if !File.exist? transcode_file
    $logger.info "failed transcode for some reason: #{file}"
    $logger.info "transcode-video -vv --no-log --encoder vt_h264 --target small --output #{transcode_file} #{file}"
  else
    finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    $total_space_reduction += Filesize.from(File.size(file).to_s + " b") - Filesize.from(File.size(transcode_file).to_s + " b")
    $logger.info "transcode finished - time: #{((finish - start)/60).ceil} minutes - smaller by: #{(Filesize.from(File.size(file).to_s + " b") - Filesize.from(File.size(transcode_file).to_s + " b")).pretty} - total space reduced: #{$total_space_reduction.pretty}"
    # $logger.info "orig size: #{File.size(file)}"
    # $logger.info "orig size pretty: #{Filesize.from(File.size(file).to_s + " b").pretty}"
    # $logger.info "size difference: #{(Filesize.from(File.size(file).to_s + " b") - Filesize.from(File.size(transcode_file).to_s + " b")).pretty}"

    FileUtils.mv file, deleteme_file
  end
end



#
# start
#

paths.each do |path|
  $logger.info "START path: #{path}"
  if Dir.exist?(path)
    files = get_files(path)
    $logger.info "#{files.count} files to process"
    $logger.info "#{files.pretty_inspect}"
    process_files files
  else
    $logger.error "path is not a dir: #{path}"
  end
end

$logger.info "extensions: #{$extensions}"
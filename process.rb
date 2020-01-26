require 'json'
require 'logger'
require 'filesize'
require 'fileutils'
require 'pp'
require 'shellwords'

$EXCLUDED_DIRS = ['/deal.with.these', '/raw', '/woodworking', '/paw patrol', '/wild.kratts', '/word world'].freeze
$PROCESS_FILE_TAGS = ['processme', 'processme1080', 'processme720', 'processmehw1080', 'processmehw720'].freeze
$VIDEO_EXTENSIONS = ['.mkv', '.mp4', '.m4v', '.divx', '.mpg', '.ts'].freeze

$logger = Logger.new('logs/process.log', 'daily')
$total_space_reduction = 0

@paths = [
          '/Volumes/storage/videos/sports',
          '/Volumes/storage/videos/movies',
          '/Volumes/storage/videos/tv.shows/'
        ]

def get_files (path)
  Dir[ File.join(path, '**', '*') ]
    .reject { |f| File.directory? f}
    .reject { |f| $EXCLUDED_DIRS.any? { |p| File.dirname(f).downcase.include? p.downcase } }
    .select { |f| $PROCESS_FILE_TAGS.any? { |p| File.basename(f).downcase.include? p.downcase } }
end

class TranscodableFile
  def initialize(file)
    @base_file = file

    # TODO if !File.file?(@base_file) raise stink
  end

  def is_video
    File.file?(@base_file) && $VIDEO_EXTENSIONS.include?(File.extname(@base_file))
  end

  def process_tag
    $PROCESS_FILE_TAGS.select { |n| File.basename(@base_file).downcase.include? '.'+n.downcase+'.'} [0]
  end

  # Return the name of the future transcoded file. 
  # So an mkv minus the process_tag
  def transcode_file
    @base_file.sub('.'+process_tag, '').sub(File.extname(@base_file), '.mkv')
  end

  # Remove the process tag and change path to videos/processed
  def moveto_file
    @base_file.sub('.'+process_tag, '').sub('videos', 'videos/processed')
  end

  def transcode
    $logger.info "transcode start: #{File.basename(@base_file)}"
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    delete_transcode_file

    transcode_video

    if !File.exist? transcode_file
      $logger.error "failed transcode for some reason: #{@base_file}"
      $logger.error "run this command to find out why it failed:: transcode-video -vv --no-log --encoder vt_h264 --target small --output #{transcode_file} #{@base_file}"
    else
      finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      start_size = Filesize.from(File.size(@base_file).to_s + " b")
      finish_size = Filesize.from(File.size(transcode_file).to_s + " b")
      smaller_by = start_size - finish_size
      elapsed_minutes = ((finish - start)/60).ceil
      $total_space_reduction += smaller_by

      $logger.info "transcode finished - time: #{elapsed_minutes} minutes - #{start_size.pretty} -> #{finish_size.pretty} - smaller by: #{smaller_by.pretty} - total space reduced: #{$total_space_reduction.pretty}"
      puts "Completed #{File.basename(@base_file)} in #{elapsed_minutes} minutes, #{finish_size.pretty}, #{smaller_by.pretty} smaller"
  
      move_base_file
    end
  end

  def transcode_video
    case process_tag
    when 'processme1080'
      %x(transcode-video --no-log --target small --output '#{Shellwords.escape(transcode_file)}' '#{Shellwords.escape(@base_file)}')
    when 'processme720'
      %x(transcode-video --no-log --720p --target small --output '#{Shellwords.escape(transcode_file)}' '#{Shellwords.escape(@base_file)}')
    when 'processmehw1080'
      %x(transcode-video --no-log --encoder vt_h264 --target small --output '#{Shellwords.escape(transcode_file)}' '#{Shellwords.escape(@base_file)}')
    when 'processmehw720', 'processme'
      %x(transcode-video --no-log --encoder vt_h264 --720p --target small --output #{Shellwords.escape(transcode_file)} #{Shellwords.escape(@base_file)})
    end
  end

  def delete_transcode_file
    if File.exist? transcode_file
      $logger.info "transcode file already exists. deleting file #{transcode_file}"
      File.delete transcode_file
    end
  end

  def move_base_file
    if !File.exist? transcode_file
      $logger.info "no moving, transcode didn't complete"
      return
    end

    folder = File.dirname(moveto_file)

    if !Dir.exist? folder
      $logger.info "move to folder doesn't exist, creating: #{folder}"
      FileUtils.mkdir_p folder
    end

    FileUtils.mv @base_file, moveto_file
  end
end

def process_files(files)
  i = files.count
  j = 0 # files processed
  files.each do |file|
    video = TranscodableFile.new(file)
    if video.is_video
      video.transcode
    else
      $logger.info "skipping #{file} because file extension says it's not a video"
    end

    j = j + 1

    avg_space_saved = $total_space_reduction / j
    # $logger.info "#{j} files processed, #{i - j} files left, #{Filesize.from(((i - j) * avg_space_saved).to_s + " b").pretty} estimated space to save"
    $logger.info "#{j} files processed, #{i - j} files left"
    
  end
end

#
# start
#

@paths.each do |path|
  $logger.info "START path: #{path}"
  p "#{path}"
  if Dir.exist?(path)
    files = get_files(path)
    $logger.info "#{files.count} files to process"
    $logger.info "#{files.pretty_inspect}"
    process_files files
  else
    $logger.error "path is not a dir: #{path}"
  end
end
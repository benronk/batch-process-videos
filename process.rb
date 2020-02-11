#!/usr/bin/env ruby

require 'json'
require 'logger'
require 'filesize'
require 'fileutils'
require 'pp'
require 'shellwords'
require 'yaml'
require 'pry'

$PROCESS_FILE_TAGS = ['processme', 'processme1080', 'processme720', 'processmehw1080', 'processmehw720'].freeze
$config = YAML.load_file("config.yml")

FileUtils.mkdir_p($config["log_loc"])
$logger = Logger.new(File.join($config["log_loc"], "process.log"), 'daily')

$total_space_reduction = 0

def get_files (path)
  Dir[ File.join(path, '**', '*') ]
    .reject { |f| File.directory? f}
    .reject { |f| ($config["excluded_dirs"] || []).any? { |p| File.dirname(f).downcase.include? p.downcase } }
    .select { |f| $PROCESS_FILE_TAGS.any? { |p| File.basename(f).downcase.include? p.downcase } }
end

class TranscodableFile
  def initialize(file, path)
    @base_file = file
    @base_path = path

    # TODO if !File.file?(@base_file) raise stink
  end

  def is_video
    File.file?(@base_file) && $config["video_extensions"].include?(File.extname(@base_file))
  end

  def process_tag
    $PROCESS_FILE_TAGS.select { |n| File.basename(@base_file).downcase.include? '.'+n.downcase+'.'} [0]
  end

  # return the name of the file while being worked
  def working_file
    File.join($config["processed_loc"], File.basename(@base_file).sub('.'+process_tag, '').sub(File.extname(@base_file), '.mkv'))
  end

  # Return the name of the future transcoded file. 
  # So an mkv minus the process_tag
  def destination_file
    @base_file.sub('.'+process_tag, '').sub(File.extname(@base_file), '.mkv')
  end

  # Remove the process tag and change path to videos/processed
  def processed_file
    last_dir_in_path = Pathname(@base_path).each_filename.to_a.last
    file_wo_path = @base_file.sub('.'+process_tag, '').sub(@base_path, '')
    File.join($config["processed_loc"], last_dir_in_path, file_wo_path)
  end

  def transcode
    $logger.info "*"*80
    $logger.info "transcode start: #{File.basename(@base_file)}"
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    delete_working_file

    transcode_video

    if !File.exist? working_file
      $logger.error "failed transcode for some reason: #{@base_file}"
      $logger.error "run this command to find out why it failed:: transcode-video -vv --no-log --encoder vt_h264 --target small --output #{working_file} #{@base_file}"
    else
      finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      start_size = Filesize.from(File.size(@base_file).to_s + " b")
      finish_size = Filesize.from(File.size(working_file).to_s + " b")
      smaller_by = start_size - finish_size
      elapsed_minutes = ((finish - start)/60).ceil
      $total_space_reduction += smaller_by

      $logger.info "transcode finished - time: #{elapsed_minutes} minutes - #{start_size.pretty} -> #{finish_size.pretty} - smaller by: #{smaller_by.pretty} - total space reduced: #{$total_space_reduction.pretty}"
      puts "Completed #{File.basename(@base_file)} in #{elapsed_minutes} minutes, #{finish_size.pretty}, #{smaller_by.pretty} smaller"
  
      move_base_file
    end
  end

  def transcode_video
    source = Shellwords.escape(@base_file)
    destination = Shellwords.escape(working_file)
    FileUtils.mkdir_p(File.dirname(working_file))
    case process_tag
    when 'processme1080'
      system("transcode-video --no-log --target small --output '#{destination}' '#{source}'")
    when 'processme720'
      system("transcode-video --no-log --720p --target small --output '#{destination}' '#{source}'")
    when 'processmehw1080'
      system("transcode-video --no-log --encoder vt_h264 --target small --output '#{destination}' '#{source}'")
    when 'processmehw720', 'processme'
      system("transcode-video --no-log --encoder vt_h264 --720p --target small --output #{destination} #{source}")
    end
  end

  def delete_working_file
    if File.exist? working_file
      $logger.info "working file already exists. deleting file #{working_file}"
      File.delete working_file
    end
  end

  def move_base_file
    # move working_file -> destination_file
    if !File.exist? working_file
      $logger.info "no moving, transcode didn't complete"
      return
    end
    $logger.info "moving #{working_file} -> #{destination_file}"
    FileUtils.mv working_file, destination_file

    # give plex time to see the new file as a duplicate
    sleep(15)

    # move base_file -> processed_file
    $logger.info "moving #{@base_file} -> #{processed_file}"
    FileUtils.mkdir_p(File.dirname(processed_file))
    FileUtils.mv @base_file, processed_file
  end
end

def squish_path(path)
  files = get_files(path)
  $logger.info "#{files.count} files to process"
  $logger.info "#{files.pretty_inspect}"

  i = files.count
  j = 0 # files processed
  files.each do |file|
    video = TranscodableFile.new(file, path)
    if video.is_video
      video.transcode
    else
      $logger.info "skipping #{file} because file extension says it's not a video"
    end

    j = j + 1

    avg_space_saved = $total_space_reduction / j
    # $logger.info "#{j} files processed, #{i - j} files left, #{Filesize.from(((i - j) * avg_space_saved).to_s + " b").pretty} estimated space to save"
    $logger.info "#{j} files processed, #{i - j} files left -> total space reduction: #{$total_space_reduction.pretty}"
    
  end
end

#
# start
#
$config["squish_paths"].each do |path|
  $logger.info "START path: #{path}"
  p "#{path}"
  if Dir.exist?(path)
    squish_path(path)
  else
    $logger.error "path is not a dir: #{path}"
  end
end

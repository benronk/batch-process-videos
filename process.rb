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
$logger = Logger.new(File.join($config["log_loc"], "process.log"), 10, 1024000)

$total_space_reduction = Filesize.from("0")

def get_files (path)
  Dir[ File.join(path, '**', '*') ]
    .reject { |f| File.directory? f}
    .reject { |f| ($config["excluded_dirs"] || []).any? { |p| File.dirname(f).downcase.include? p.downcase } }
    .select { |f| $PROCESS_FILE_TAGS.any? { |p| File.basename(f).downcase.include? p.downcase } }
end

class TranscodableFile
  def initialize(file, path)
    @origional_file = file
    @origional_path = path

    # TODO if !File.file?(@origional_file) raise stink
  end

  def video?
    File.file?(@origional_file) && $config["video_extensions"].include?(File.extname(@origional_file))
  end

  def recently_modified?(file, seconds_ago=30)
    modified_seconds_ago = Time.now - File.stat(file).mtime
    modified_seconds_ago < seconds_ago
  end

  def process_tag
    $PROCESS_FILE_TAGS.select { |n| File.basename(@origional_file).downcase.include? '.'+n.downcase+'.'} [0]
  end

  # return the name of the file while being worked
  def temp_file
    File.join($config["processed_loc"], File.basename(@origional_file).sub('.'+process_tag, '').sub(File.extname(@origional_file), '.mkv'))
  end

  # Return the name of the future transcoded file. 
  # So an mkv minus the process_tag
  def destination_file
    @origional_file.sub('.'+process_tag, '').sub(File.extname(@origional_file), '.mkv')
  end

  # Remove the process tag from origional file 
  # and change path to processed location
  def processed_file
    last_dir_in_path = Pathname(@origional_path).each_filename.to_a.last
    file_wo_path = @origional_file.sub('.'+process_tag, '').sub(@origional_path, '')
    File.join($config["processed_loc"], last_dir_in_path, file_wo_path)
  end

  def failed_file
    last_dir_in_path = Pathname(@origional_path).each_filename.to_a.last
    file_wo_path = @origional_file.sub(@origional_path, '')
    File.join($config["failed_loc"], last_dir_in_path, file_wo_path)
  end

  def transcode
    $logger.info "transcode start: #{File.basename(@origional_file)}"
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    transcode_video

    if !File.exist? temp_file
      $logger.error "failed transcode for some reason: #{@origional_file}"
      $logger.error "run this command to find out why it failed:: transcode-video -vv --no-log --encoder vt_h264 --target small --output #{temp_file} #{@origional_file}"
      move_origional_to_failed
    else
      finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      start_size = Filesize.from(File.size(@origional_file).to_s + " b")
      finish_size = Filesize.from(File.size(temp_file).to_s + " b")
      smaller_by = start_size - finish_size
      elapsed_minutes = ((finish - start)/60).ceil
      $total_space_reduction += smaller_by

      move_temp_to_destination
      $logger.info "transcode finished - time: #{elapsed_minutes} minutes - #{start_size.pretty} -> #{finish_size.pretty} - smaller by: #{smaller_by.pretty} - total space reduced: #{$total_space_reduction.pretty}"
      puts "Completed #{File.basename(@origional_file)} in #{elapsed_minutes} minutes, #{finish_size.pretty}, #{smaller_by.pretty} smaller"
  
    end
  end

  def transcode_video
    source = Shellwords.escape(@origional_file)
    destination = Shellwords.escape(temp_file)
    FileUtils.mkdir_p(File.dirname(temp_file))
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

  # see if temp file exists
  # if it's changing size then skip this video as another process is doing the same thing
  # otherwise assume it's left over and delete it
  def already_being_processed?
    # if origional exists and destination has existed for 30s+
    # assume a previous run didn't get around to cleaning up the file
    if(File.exist?(@origional_file) && File.exist?(destination_file) && !recently_modified?(destination_file))
      $logger.info "Found origional and transcoded file; moving origional"
      move_origional_file
      return true
    end

    if File.exist? temp_file
      # if file has been modified in the last 30 seconds consider it in flight by another
      if recently_modified?(temp_file)
        $logger.info "  temp file modified recently (maybe by another process?) so skipping #{temp_file}"
        return true
      else
        $logger.info "  temp file is old, deleting #{temp_file}"
        File.delete temp_file
      end
    end
    false
  end

  def delete_temp_file
    if File.exist? temp_file
      $logger.info "  temp file already exists, deleting #{temp_file}"
      File.delete temp_file
    end
  end

  # move temp_file -> destination_file
  def move_temp_to_destination
    if !File.exist? temp_file
      $logger.info "no moving, transcode didn't complete"
      return
    end
    $logger.info "  moving (temp->destination)\n  #{temp_file} ->\n  #{destination_file}"
    FileUtils.mv temp_file, destination_file
  end

  # move origional_file -> processed_file
  def move_origional_file
    if File.exist? @origional_file
      $logger.info "  moving previous (orig->processed)\n  #{@origional_file} ->\n  #{processed_file}"
      FileUtils.mkdir_p(File.dirname(processed_file))
      FileUtils.mv @origional_file, processed_file
    end
  end

  def move_origional_to_failed
    if File.exist? @origional_file
      $logger.info "  moving failed file (orig->failed)\n  #{@origional_file} ->\n  #{failed_file}"
      FileUtils.mkdir_p(File.dirname(failed_file))
      FileUtils.mv @origional_file, failed_file
    end
  end
end

def squish_path(path)
  files = get_files(path)
  $logger.info "#{files.count} files to process"
  $logger.info "#{files.pretty_inspect}"

  total_files = files.count
  files_processed = 0
  previous_video = nil
  files.each do |file|
    $logger.info "*"*80
    video = TranscodableFile.new(file, path)
    if video.video?
      if !video.already_being_processed?
        video.transcode
      else
        next
      end
    else
      $logger.info "  skipping #{file} because file extension says it's not a video"
      next
    end

    previous_video.move_origional_file if previous_video
    previous_video = video

    files_processed = files_processed + 1

    avg_space_saved = $total_space_reduction / files_processed
    # $logger.info "#{files_processed} files processed, #{total_files - files_processed} files left, #{Filesize.from(((total_files - files_processed) * avg_space_saved).to_s + " b").pretty} estimated space to save"
    $logger.info "#{files_processed} files processed, #{total_files - files_processed} files left -> total space reduction: #{$total_space_reduction.pretty}"
    
  end

  if previous_video
    # logger waiting for Plex to pickup last new file
    $logger.info "Waiting 30s for Plex to pickup new file"
    sleep(30)
    previous_video.move_origional_file 
  end
end

#
# start
#
$config["squish_paths"].each do |path|
  $logger.info "*"*80
  $logger.info "START path: #{path}"
  p "#{path}"
  if Dir.exist?(path)
    squish_path(path)
  else
    $logger.error "path is not a dir: #{path}"
  end
end

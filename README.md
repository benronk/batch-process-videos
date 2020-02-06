# batch-process-videos

## Installation

    brew install handbrake
    brew install ffmpeg
    brew install mkvtoolnix
    brew install mp4v2
    bundle install

## process.rb

Batch process video files and transcode them smaller.

I've been using [Don Melton's transcode-video](https://github.com/donmelton/video_transcoding) scripts to transcode my video library for awhile now but what I really wanted was a simple way to batch transcode multiple files. This script does that.

Rename the files to be transcoded with a process tag. Add it at the end of the filename before the file extension with a `.`. So `filename.process-tag.extension`. 

Example:

If you want to transcode this file:

`/videos/movies/The Best Movie Evar.mkv`

rename it accordingly: 

`/videos/movies/The Best Movie Evar.processme.mkv`

^ That renamed file will be transcoded. The transcoded file will be saved as `/videos/movies/The Best Movie Evar.mkv` (the same place, same name as the origional). The origional file has the process-tag removed and moved to `/videos/processed/movies/The Best Movie Evar.mkv`.

Valid process tags:

* `processme` - choose the default encode, currently processmehw720
* `processme1080` - use transcode-video's default settings at 1080p
* `processme720` - use transcode-video's default settings at 720p
* `processmehw1080` - use your computers hardware encoding (if available) at 1080p
* `processmehw720` - use your computers hardware encoding (if available) at 720p

## get-video-properties

Will return a video file's video properties. 

`ruby get-video-properties.rb /videos/movies/The Best Movie Evar.mkv` will return something like:

``` json
/videos/movies/The Best Movie Evar.mkv => [
  {
    "codec_type": "video",
    "codec_name": "h264",
    "codec_long_name": "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10",
    "height": 808,
    "coded_height": 816
  }
]
```

My origional plan was to use this information to determine how to transcode a file because I wanted to keep a 1080 and 720 version of the file, to avoid transcoding whenever possible. Transcoding down to 720 on the fly is no longer an issue for me so I kept this code here as a neat example of what could be done.

## get-all-file-types

Returns all of the file types in the target path (hardcoded in the script). Output looks like:
`extensions: [".mkv", ".mp4", ".jpg", ".srt", ".avi", ".txt", ".m4v", ".part", ".3gp", ".BUP", ".IFO", ".VOB", ".json", ".xml", ".ISO", ".divx", ".rar", ".mpg", ".mp3", ".docx"]`

## move-em-all

Moves files from one place to another. I used this once for something. It's kinda pointless but i wanted it to stick around if I ever used it again.
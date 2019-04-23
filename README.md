# batch-process-videos


## process.rb

Batch process video files and transcode them smaller.

I've been using [Don Melton's transcode-video](https://github.com/donmelton/video_transcoding) scripts to transcode my video library for awhile now, but what I really wanted was a simple way to batch transcode multiple files. This script does that.

Simply put the video files or the folders containing the video files into a folder named `processme` and the script will pick them up and transcode them. The origional file is moved to a `processed` folder incase something goes awry. The transcoded file is created in the origional file's path, minus the `processme` folder.

So a file in this processme folder: 
`/Volumes/storage/videos/movies/processme/The Best Movie Evar.mkv` 
will have its transcoded file created here: 
`/Volumes/storage/videos/movies/The Best Movie Evar.mkv` 

OR 
`/Volumes/storage/videos/tv.shows/Big.Bang.Theory/processme/Season.09/Big.Bang.Theory.S09.E01.mkv` 
will be transcoded and created here: 
`/Volumes/storage/videos/tv.shows/Big.Bang.Theory/Season.09/Big.Bang.Theory.S09.E01.mkv` 

So 'queueing' up a single file, an entire season of shows, or an entire show and all of its seasons simply requires putting those files/folders inside a `processme` folder.

## get-video-properties

Will return a video file's video properties. 

`ruby get-video-properties.rb /Volumes/storage/videos/movies/The Best Movie Evar.mkv` will return something like:

``` json
/Volumes/storage/videos/movies/The Best Movie Evar.mkv => [
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
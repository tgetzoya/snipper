# Snipper
  A shell script that extracts either a single image, a set of images, or a snippet of video from a video file.

## Usage
  ./snip.sh -i <infile> -o <outfile_name> -f <format> -s <start_time_in_seconds> -l <duration_in_second> -d <destination_directory> -q -c -v -h
  
## Parameters
  -i, --infile: In file. I.E. The file to work with.
  
  -o (lowercase letter o), --outname: The name of the output file.
  
  -f, --format: The type of desired output (video or images(s)). Case insensitive.
  
      Option: \"image\" For a single image.
  
      Option: \"book\" For one image per second until either -l or end-of-file.
  
      Option: \"video\" To return a sub-length of the file from either 0 or -s and -l or end-of-file.
  
  -s, --start: The offset to begin taking image(s) or start video. This is an integer value in seconds.
  
  -l  (lowercase letter l), --length: The length of images or video to take in seconds. This value is ignored for single images."
  
  -d, --destination: The destination directory for the output file.
  
  -q, --quality: Image output will be in PNG instead of JPEG. Creates larger files but preserves quality. Ignored by the \"video\" option.
  
  -c, --compress: Compress output into single file. Currently only supports tar.gz format and only used with the \"book\" option.
  
  -v, --verbose: Verbose mode. Prints to stdout and stderr. Default is to not print to stdout or stderr.
  
  -h, --help: Help. Prints this information to stdout and exits. All other flags will be ignored.
  
## Examples:
  One image at the 12th second of video. Use png instead of jpg.
  
      ./snip.sh -i ./in_file.mp4 -o output_name -f image -s 12 -q
  
  A set of images, one at each second, starting at the 5th second and continuing for 3 seconds. Show output.
  
      ./snip.sh -i ./in_file.mp4 -o output_name -f book -s 5 -l 3 -v
  
  A set of images, one at each second, starting at the 4th second and continuing for 4 seconds. Compress to output_name.tar.gz.
  
      ./snip.sh -i ./in_file.mp4 -o output_name -f book -s 4 -l 4 -c
  
  A video starting at the beginning and lasting for 6 seconds.
  
      ./snip.sh -i ./in_file.mp4 -o output_name -f video -l 6
  
  A video with the first 7 seconds removed. The output file will be put in the users home directory.
  
      ./snip.sh -i ./in_file.mp4 -o output_name -f video -s 8 -d
  
  A video starting at the 1st second and lasting for 2 seconds.
  
      ./snip.sh -i ./in_file.mp4 -o output_name -f video -s 1 -l 2

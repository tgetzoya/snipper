#!/bin/sh

########################################################################################################################
# Copyright 2021 Thomas Getzoyan <tgetzoya@gmail.com>
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
# following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following
#    disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
#    following disclaimer in the documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote
#    products derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

########################################################################################################################
# A shell script that (currently) uses ffmpeg to extract either a single image, a set of images, or a snippet of video
# from a video file. Also has the ability to compress a set of extracted images into a tar.gz file. Does all its work
# within the /tmp/ directory and will place the resulting file(s) into either its own directory or one given by the
# user.

# Effort was made to make this script POSIX compliant as much as possible. It has been tested on the following:
# 1) X86-64 Linux: Arch Linux with latest kernel
# 2) ARM MacOS: macOS Big Sur 11.3.1 on Apple Silicon M1

# The only dependency this script needs is a video encoder/decoder, currently ffmpeg. It must be installed separately.

########################################################################################################################
# Variables

NAME="snip"
VIDEO_APP="ffmpeg"
UUID=$(uuidgen)
WORKING_DIR="/tmp/${NAME}er/${UUID}"
COMPRESSION=""
DURATION=""
FORMAT=""
QUALITY=""
START=""
VERBOSE=""

########################################################################################################################
# Functions

run_command() {
  if [ -n "$VERBOSE" ]; then
    eval "$1"
  else
    eval "$1" > /dev/null 2>&1
  fi
}

show_message() {
  if [ -n "$VERBOSE" ]; then
    echo "$1"
  fi
}

show_help() {
  echo "Usage: $NAME -i <infile> -o <outfile_name> -f <format> -s <start_time_in_seconds> -l <duration_in_second> -d <destination_directory> -q -c -v -h"
  echo "-i, --infile: In file. I.E. The file to work with."
  echo "-o (lowercase letter o), --outname: The name of the output file."
  echo "-f, --format: The type of desired output (video or images(s)). Case insensitive."
  echo "    Option: \"image\" For a single image."
  echo "    Option: \"book\" For one image per second until either -l or end-of-file."
  echo "    Option: \"video\" To return a sub-length of the file from either 0 or -s and -l or end-of-file."
  echo "-s, --start: The offset to begin taking image(s) or start video. This is an integer value in seconds."
  echo "-l  (lowercase letter l), --length: The length of images or video to take in seconds. This value is ignored for single images."
  echo "-d, --destination: The destination directory for the output file."
  echo "-q, --quality: Image output will be in PNG instead of JPEG. Creates larger files but preserves quality. Ignored by the \"video\" option."
  echo "-c, --compress: Compress output into single file. Currently only supports tar.gz format and only used with the \"book\" option."
  echo "-v, --verbose: Verbose mode. Prints to stdout and stderr. Default is to not print to stdout or stderr."
  echo "-h, --help: Help. Prints this information to stdout and exits. All other flags will be ignored."
  printf "\nExamples:\n\n"
  printf "One image at the 12th second of video\n\t./%s.sh -i ./in_file.mp4 -o output_name -f image -s 12 -v\n\n" $NAME
  printf "A set of images, one at each second, starting at the 5th second and continuing for 3 seconds. Show output.\n"
  printf "\t./%s.sh -i ./in_file.mp4 -o output_name -f book -s 5 -l 3 -v\n\n" $NAME
  printf "A set of images, one at each second, starting at the 4th second and continuing for 4 seconds. Compress to output_name.tar.gz.\n"
  printf "\t./%s.sh -i ./in_file.mp4 -o output_name -f book -s 4 -l 4 -c\n\n" $NAME
  printf "A video starting at the beginning and lasting for 6 seconds.\n\t./%s.sh -i ./in_file.mp4 -o output_name -f video -l 6\n\n" $NAME
  printf "A video with the first 7 seconds removed. The output file will be put in the users home directory.\n"
  printf "\t./%s.sh -i ./in_file.mp4 -o output_name -f video -s 8 -d ~/\n\n" $NAME
  printf "A video starting at the 1st second and lasting for 2 seconds.\n\t./%s.sh -i ./in_file.mp4 -o output_name -f video -s 1 -l 2\n\n" $NAME
  exit
}
########################################################################################################################
# Parameter Parser

while test -n "$1"; do
  case "$1" in
  -c | --compress)
    COMPRESSION="YES"
    shift 1
    ;;
  -d | --destination)
    DESTINATION=${2:?"Destination parameter is given but no value is defined. Program will now exit."}
    shift 2
    ;;
  -f | --format)
    FORMAT=${2:?"Format parameter is given but no value is defined. Program will now exit."}
    shift 2
    ;;
  -i | --infile)
    INFILE=${2:?"Input parameter is given but no value is defined. Program will now exit."}
    shift 2
    ;;
  -l | --length)
    DURATION=${2:?"Length parameter is given but no value is defined. Program will now exit."}
    shift 2
    ;;
  -o | --outname)
    OUTFILE=${2:?"Output parameter is given but no value is defined. Program will now exit."}
    shift 2
    ;;
  -q | --quality)
    QUALITY="YES"
    shift 1
    ;;
  -s | --start)
    START=${2:?"Timestamp is not set. Program will now exit."}
    shift 2
    ;;
  -v | --verbose)
    VERBOSE="YES"
    shift 1
    ;;
  -h | --help)
    show_help
    exit
    ;;
  *)
    show_message "Unknown command: $1"
    shift 1
    ;;
  esac
done

########################################################################################################################
# Input validators

if ! command -v $VIDEO_APP >/dev/null 2>&1; then
  show_message "$VIDEO_APP is not installed or not in $PATH.Program will now exit."
  exit 1
fi

if [ ! -d "$WORKING_DIR" ]; then
  if ! mkdir -p "$WORKING_DIR"; then
    show_message "Could not create working directory. Program will now exit."
    exit 1
  fi
fi

if [ -z "$INFILE" ]; then
  show_message "Input file is not set. Program will now exit."
  exit 1
fi

if [ -z "$OUTFILE" ]; then
  show_message "Output file is not set. Program will now exit."
  exit 1
fi

if [ -z "$FORMAT" ]; then
  show_message "Format is not set. Program will now exit."
  exit 1
fi

if [ -z "$START" ]; then
  START=0
fi

if [ -z "$DESTINATION" ]; then
  DESTINATION=$PWD
fi

########################################################################################################################
# System checks

# Check whether the destination directory is writable
if ! touch "$DESTINATION"/temp.file >/dev/null 2>&1; then
  show_message "Could not write into destination directory: $DESTINATION. Program will now exit."
  exit 1
else
  rm -rf "$DESTINATION"/temp.file
fi

# Uppercase the input for easier parsing
FORMAT=$(echo "$FORMAT" | awk '{print toupper($0)}')

# For book and video types, the user can set an end-time as well
if [ "$FORMAT" = "BOOK" ] || [ "$FORMAT" = "VIDEO" ]; then
  if [ -n "$DURATION" ]; then
    DURATION="-t ${DURATION}"
  fi
fi

# Set up the type of output the user is expecting
case $FORMAT in
"IMAGE")
  COMMAND="ffmpeg -i $INFILE -ss $START -frames:v 1 $WORKING_DIR/${OUTFILE}.jpg"
  ;;
"BOOK")
  COMMAND="ffmpeg -i $INFILE -ss $START $DURATION -r 1 $WORKING_DIR/${OUTFILE}%03d.jpg"
  ;;
"VIDEO")
  COMMAND="ffmpeg -i $INFILE -c copy -ss $START $DURATION $WORKING_DIR/${OUTFILE}.mp4"
  ;;
*)
  show_message "Unknown format: $FORMAT. Exiting."
  exit 1
  ;;
esac

# User PNG instead of JPG if requested
if [ -n "$QUALITY" ]; then
  COMMAND=$(echo "$COMMAND" | sed -e 's/.jpg/.png/g')
fi

########################################################################################################################
# Execution

# FFmpeg command execution is done here
run_command "$COMMAND"

# If compression was requested, do it here
if [ "$FORMAT" = "BOOK" ] && [ -n "$COMPRESSION" ]; then
  show_message "Compressing output into zip file"
  cd "$WORKING_DIR" || return

  COMMAND="tar cvzf $OUTFILE.tar.gz ./*"

  run_command "$COMMAND"

  show_message "Moving compressed file to destination"
  cp "$OUTFILE".tar.gz "$DESTINATION"
  cd "$HERE" || return
else
  show_message "Moving files to destination"
  cp "$WORKING_DIR"/* "$DESTINATION"
fi

########################################################################################################################
# Cleanup

# Finally, clean up working directory
show_message "Cleaning working directory"
rm -rf "$WORKING_DIR"

########################################################################################################################
# Complete

show_message "Done."
exit 0

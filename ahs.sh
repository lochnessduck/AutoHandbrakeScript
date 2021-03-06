#!/bin/bash
#ahs.sh

###############################################################################
#   AutoHandbrakeScript
#   Copyright (C) 2009-2011  Curtis Lee Bolin <curtlee2002(at)gmail.com>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
###############################################################################

fileType=( avi flv iso mov mp4 mpeg mpg ogg ogm ogv wmv m2ts rmvb rm 3gp m4a 3g2 mj2 asf divx vob mkv )

readonly DEFAULT_VIDEO_SETTINGS="--encoder x264 --two-pass --turbo --decomb --loose-anamorphic"

#--preset slow
#readonly DEFAULT_X264_SETTINGS="--encopts b-adapt=2:direct=auto:me=umh:rc-lookahead=50:ref=5:subme=8"

#--preset slower
#readonly DEFAULT_X264_SETTINGS="--encopts b-adapt=2:direct=auto:me=umh:partitions=all:rc-lookahead=60:ref=8:subme=9:trellis=2"

#--preset veryslow
readonly DEFAULT_X264_SETTINGS="--encopts b-adapt=2:bframes=8:direct=auto:me=umh:merange=24:partitions=all:ref=16:subme=10:trellis=2:rc-lookahead=60"

readonly DEFAULT_AUDIO_SETTINGS="--audio 1 --aencoder vorbis --aq 0.3 --mixdown dpl2 --arate 48 --drc 2.5"
readonly DEFAULT_CHAPTER_SETTINGS="--markers"
readonly DEFAULT_CONTAINER_TYPE="mkv"
readonly DEFAULT_CONTAINER_SETTINGS="--format $DEFAULT_CONTAINER_TYPE"
readonly DEFAULT_LOG_FILE="handbrake.log"
readonly DEFAULT_PROCESSED_DIRECTORY="processed"
readonly DEFAULT_OUTPUT_DIRECTORY="output"
readonly DEFAULT_SKIP_DIRECTORY="skip"
readonly EMPTY_STRING=''
subtitleSettings=""
outputDirectory="$DEFAULT_OUTPUT_DIRECTORY"
otherSettings=""
mode=""
audioNumber=""
encoderCopy=""
titleOptions=""
titleCount=""
fileName=""
scanList=""
cropFlag=false
audioCopy=false

Logger ()
{
   echo "$(date +'[ %d %b %Y %H:%M:%S ]') :: $*" | tee -a "$DEFAULT_PROCESSED_DIRECTORY"/"$DEFAULT_LOG_FILE"
}

CheckVideo ()
{
   videoWidth=${scanList#*job->width:}
   videoWidth=${videoWidth%,\ job->*}
   videoHeight=${scanList#*,\ job->height:}
   videoHeight=${videoHeight%[*}
   videoHeight=${videoHeight%S*}
   videoBitRate="$(echo sqrt\($videoWidth*$videoHeight\) | bc)"
}

CheckAudio ()
{
   audioChannelList=${scanList#*+\ audio\ tracks:}
   audioChannelList=${audioChannelList%+\ subtitle\ tracks:*}
   audioChannelList=${audioChannelList// /} # replace " " with ""
   audioCount="1"
   for item in $(echo $audioChannelList | sed -e 's/+/\n/g')
   do
      echo $item
      if $(echo $item | grep "AC3" | grep "5.1" | grep -q "384000bps") || $audioCopy
      then
         if [ "$audioCount" == "1" ]
         then
            audioTracks="$audioCount"
            audioEncoder="copy:ac3"
            audioBitrate="384"
            audioQuality="$EMPTY_STRING"
            audioSampleRate="48"
            drc="2.5"
         else
            audioTracks="$audioTracks,$audioCount"
            audioEncoder="$audioEncoder,copy:ac3"
            audioBitrate="$audioBitrate,384"
            audioQuality="$audioQuality,$EMPTY_STRING"
            audioSampleRate="$audioSampleRate,48"
            drc="$drc,2.5"
         fi
      elif $(echo $item | grep -q -e "5.1")
      then
         if [ "$audioCount" == "1" ]
         then
            audioTracks="$audioCount"
            audioEncoder="ffac3"
            audioBitrate="384"
            audioQuality="$EMPTY_STRING"
            audioSampleRate="48"
            drc="2.5"
         else
            audioTracks="$audioTracks,$audioCount"
            audioEncoder="$audioEncoder,ffac3"
            audioBitrate="$audioBitrate,384"
            audioQuality="$audioQuality,$EMPTY_STRING"
            audioSampleRate="$audioSampleRate,48"
            drc="$drc,2.5"
         fi
      else
         if [ "$audioCount" == "1" ]
         then
            audioTracks="$audioCount"
            audioEncoder="vorbis"
            audioBitrate="$EMPTY_STRING"
            audioQuality="0.3"
            audioSampleRate="48"
            drc="2.5"
         else
            audioTracks="$audioTracks,$audioCount"
            audioEncoder="$audioEncoder,vorbis"
            audioBitrate="$audioBitrate,$EMPTY_STRING"
            audioQuality="$audioQuality,0.3"
            audioSampleRate="$audioSampleRate,48"
            drc="$drc,2.5"
         fi
      fi
      ((audioCount++))
   done
   audioSettings="--audio $audioTracks --aencoder $audioEncoder --aq $audioQuality --ab $audioBitrate --arate $audioSampleRate --drc $drc"
}

CheckSubtitles ()
{
   subtitleChannelList=${scanList#*+\ subtitle\ tracks:}
   subtitleChannelList=${subtitleChannelList%HandBrake\ has\ exited.*}
   subtitleChannelCount=$(echo $subtitleChannelList | sed -e 's/+/\n/g' | wc -l)
   if [ "$subtitleChannelCount" == "0" ]
   then
      subtitleSettings=""
   else
      subtitleNumbers="1"
      ((subtitleChannelCount--))  # to not count the first blank line
      if [ "$subtitleChannelCount" != "1" ]
      then
         for (( i=2; i<="$subtitleChannelCount"; i++ ))
         do
            subtitleNumbers="$subtitleNumbers,$i"
         done
      fi
      subtitleSettings="--subtitle $subtitleNumbers"
   fi
}

FileTranscode ()
{
   [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
   [ ! -d "$outputDirectory" ] && mkdir -p "$outputDirectory"
   [ "${inputFileName##*.}" != "iso" ] && titleOptions=""
   mv "$inputFileName" "$DEFAULT_PROCESSED_DIRECTORY"/
   scanList=$(HandBrakeCLI --scan $titleOptions --input "$DEFAULT_PROCESSED_DIRECTORY"/"$inputFileName" 2>&1)
   CheckVideo
   CheckAudio
   CheckSubtitles
   Logger "Encoding $inputFileName to $videoName.$DEFAULT_CONTAINER_TYPE ..."
   HandBrakeCLI $DEFAULT_VIDEO_SETTINGS $DEFAULT_X264_SETTINGS --vb $videoBitRate $audioSettings $subtitleSettings $DEFAULT_CONTAINER_SETTINGS $DEFAULT_CHAPTER_SETTINGS $otherSettings --input "$(pwd)"/"$DEFAULT_PROCESSED_DIRECTORY"/"$inputFileName" --output "$(pwd)"/"$outputDirectory"/"$videoName"."$DEFAULT_CONTAINER_TYPE"
   Logger "Encoding Completed."
}

FileSearch ()
{
   for inputFileName in *
   do
      if [ -f "$inputFileName" ]  # test if it is a true file
      then
         fileNameExt="${inputFileName##*.}"  # extracts the extension from the file name
         for (( i=0 ; i!=${#fileType[@]} ; i++))
         do
            if [ "${fileType[$i]}" == "$fileNameExt" ]
            then
               videoName=${inputFileName%.*}  # extracts the video name from the file name
               $encodeCommand
               break
            fi
         done
      fi
   done
}

IsoTranscode ()
{
   [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
   [ ! -d "$outputDirectory" ] && mkdir -p "$outputDirectory"
   mv "$inputFileName" "$DEFAULT_PROCESSED_DIRECTORY"/
   outputDirectory="${inputFileName%.*}"
   titleCount=$(HandBrakeCLI --scan --input "$DEFAULT_PROCESSED_DIRECTORY"/"$inputFileName" 2>&1 | grep "scan: DVD has")
   titleCount="${titleCount:25}"
   titleCount="${titleCount%\ title(s)}"
   for (( count=1; count <= "$titleCount"; count++ ))
   do
      [ "$count" -lt "10" ] && number=0$count || number=$count
      [ $mode == "TitleMode" ] && titleOptions="--title $count" && otherSettings="$titleOptions" && videoName="Title$number"
      [ $mode == "ChapterMode" ] && otherSettings="--chapters $count $titleOptions" && videoName="Chapter$number"
      FileTranscode
   done
}

ChapterMode ()
{
   fileType=( iso )
   [ -z titleOptions ] && titleOptions="--main-feature"
   if [ -n "$fileName" ]
   then
      inputFileName="$fileName"
      IsoTranscode
   else
      encodeCommand="IsoTranscode"
      FileSearch
   fi
}

TitleMode ()
{
   fileType=( iso )
   if [ -n "$fileName" ]
   then
      inputFileName="$fileName"
      if [ -n "$titleOptions" ]
      then
         otherSettings="$titleOptions"
         FileTranscode
      else
         titleOptions="--main-feature"
         otherSettings="$titleOptions"
         IsoTranscode
      fi
   else
      encodeCommand="IsoTranscode"
      FileSearch
   fi
}

DirectoryMode ()
{
   startingDiretory=$(pwd)
   encodeCommand="FileTranscode"
   FileSearch
   for directoryName in *
   do
      if [[ -d "$directoryName" && "$directoryName" != "$DEFAULT_PROCESSED_DIRECTORY" && "$directoryName" != "$DEFAULT_OUTPUT_DIRECTORY" && "$directoryName" != "$DEFAULT_SKIP_DIRECTORY" ]]
      then
         cd "$directoryName"
         FileSearch
         #######################################################################
         for directoryName in *
         do
            if [[ -d "$directoryName" && "$directoryName" != "$DEFAULT_PROCESSED_DIRECTORY" && "$directoryName" != "$DEFAULT_OUTPUT_DIRECTORY" && "$directoryName" != "$DEFAULT_SKIP_DIRECTORY" ]]
            then
               cd "$directoryName"
               FileSearch
               cd ../
            fi
         done
         #######################################################################
         cd ../
      fi
   done
   cd "$startingDiretory"
}

SimpleDirectoryMode ()
{
   encodeCommand="FileTranscode"
   FileSearch
}

FileMode ()
{
   [ ! -d "$DEFAULT_PROCESSED_DIRECTORY" ] && mkdir -p "$DEFAULT_PROCESSED_DIRECTORY"
   inputFileName="$fileName"
   videoName="${inputFileName%.*}"
   FileTranscode
}

ErrorFound ()
{
   [ -z "$error" ] && error="Unrecognized option: $@"
   echo
   echo "**********Error with options**********"
   echo
   echo "Error: $error"
   echo
   echo "**************************************"
   PrintUsage
   exit 1
}

PrintUsage ()
{
echo
echo "Usage: $0 [OPTION]"
cat << EOF

Modes:

   -C, --chapter [TITLE]
      Transcodes each chapter of the main feature title or title number given
      of the iso files in that directory or file given as input.

   -T, --title [TITLE] copy
      Transcodes each title or title number given
      of the iso files in that directory or file given as input.
      If copy is set then audio tracks are copied instead of trancoded.

   -D, --directory
      Transcodes files two directories deep.

   With no mode selected all video files in the directory will be transcoded
   and main feature title of an iso files unless an input file is given.

Other Options:

   -i, --input [FILE]
      If a file name is given, only that file will be encoded

   -c, --crop <T:B:L:R>
      Manually sets the cropping
      Top:Bottom:Left:Right

   -h, --help
      Prints this help information.

EOF
}

if [ -z "$1" ]
then
   SimpleDirectoryMode
else
   until [ -z "$1" ]; do
      # use a case statement to test vars. we always test
      # test $1 and shift at the end of the for block.
      case $1 in
         -h|--help)
            PrintUsage
            exit 0
         ;;
         -C|--chapter )
            # shift, so the string after -c or --chapter becomes our new $1
            [ -n "$mode" ] && error="Only one mode can be selected." && ErrorFound
            shift
            [ -n "$1" -a "$1" != "-*" ] && titleOptions="--title $1"
            mode="ChapterMode"
         ;;
         -T|--title )
            [ -n "$mode" ] && error="Only one mode can be selected." && ErrorFound
            [ -n "$2" -a "${2:0:1}" != "-" -a "$2" != "copy" ] && shift && titleOptions="--title $1"
            [ -n "$2" -a "copy" ] && shift && audioCopy=true
            mode="TitleMode"
         ;;
         -D|--directory )
            [ -n "$mode" ] && error="Only one mode can be selected." && ErrorFound
            [ -n "$2" -a "$2" = "-i" ] && error="Can't use input file with directory mode" && ErrorFound
            mode="DirectoryMode"
         ;;
         -c|--crop )
            [ $cropFlag ] && error="Only one crop can be set." && ErrorFound
            cropFlag=true
            shift
            otherSettings="$otherSettings --crop $1"
         ;;
         -i|--input )
            shift
            if [ -n "$1" -a "${1:0:1}" != "-" ] # "${1:0:1}" gets the first charater of string $1
            then
               fileName="$1"
            else
               error="$1 is not a valid input file."
               ErrorFound
            fi
         ;;
         * )
            ErrorFound $@
         ;;
      esac

      shift

      if [ "$#" = "0" ]; then
         break
      fi
   done
fi

[ -z "$mode" ] && mode="SimpleDirectoryMode"
$mode

exit 0

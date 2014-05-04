#!/bin/bash


# ================================= FUNCTIONS =================================

function help() {
	less <<< 'BPMWRAP

Description:
	This BASH script is a wrapper for bpm-tag utility of bpm-tools and several 
	audio tagging utilities. The purpose is to make BPM (beats per minute) 
	tagging as easy as possible.  
	Default behaviour is to look through working directory for *.mp3 files 
	and compute and print their BPM in the following manner: 
		[current (if any)] [computed] [filename]

Usage:
	bpmwrap [options] [directory or filenames]

Options:
	You can specify files to process by one of these ways:
		1) state files and/or directories containing them after options
		2) specify --import file
		3) specify --input file
	With either way you still can filter the resulting list using --type option(s).
	Remember that the script will process only mp3 files by default, unless 
	specified otherwise!

	-i, --import file
		Use this option to set BPM tag for all files in given file instead of 
		computing it. Expected format of every row is BPM number and absolute path 
		to filename separated by semicolon like so:
			145;/home/trinity/music/Apocalyptica/07 beyond time.mp3
		Remember to use --write option too.
	-n, --input file
		Use this option to give the script list of FILES to process INSTEAD of paths 
		where to look for them. Each row whould have one absolute path. 
		This will bypass the searching part and is that way useful when you want 
		to process large number of files several times. Like when you are not yet 
		sure what BPM limits to set. Extension filtering will still work.
	-o, --output file
		Save output also to a file.
	-l, --list-save file
		Save list of files about to get processed. You can use this list later 
		as a file for --input option.
	-t, --type filetype
		Extension of file type to work with. Defaults to mp3. Can be specified 
		multiple times for more filetypes. Currently supported are mp3 ogg flac.
	-e, --existing-only
		Only show BPM for files that have it. Do NOT compute new one.
	-w, --write 
		Write computed BPM to audio file but do NOT overwrite existing value.
	-f, --force
		Write computed BPM to audio file even if it already has one. Aplicable only 
		with --write option.
	-m, --min minbpm
		Set minimal BPM to look for when computing. Defaults to bpm-tag minimum 84.
	-x, --max maxbpm
		Set maximal BPM to look for when computing. Defaults to bpm-tag maximum 146.
	-v, --verbose
		Show "progress" messages.
	-c, --csv-friendly
		Use semicolon (;) instead of space to separate output columns.
	-h, --help
		Show this help.

License:
	GPL V2

Links:
	bpm-tools (http://www.pogo.org.uk/~mark/bpm-tools/)

Dependencies:
	bpm-tag mid3v2 vorbiscomment metaflac

Author:
	Martin Lukeš (martin.meridius@gmail.com)
	Based on work of kolypto (http://superuser.com/a/129157/137326)
	'
}

# Usage: result=$(inArray $needle haystack[@])
# @param string needle
# @param array haystack
# @returns int (1 = NOT / 0 = IS) in array
function inArray() {
	needle="$1"
	haystack=("${!2}")
	out=1
	for e in "${haystack[@]}" ; do 
		if [[ "$e" = "$needle" ]] ; then
			out=0
			break
		fi
	done
	echo $out
}

# Usage: result=$(implode $separator array[@])
# @param char separator
# @param array array to implode
# @returns string separated array elements
function implode() {
	separator="$1"
	array=("${!2}")
	IFSORIG=$IFS
	IFS="$separator"
	echo "${array[*]}"
	IFS=$IFSORIG
}

# @param string file
# @returns int BPM value
function getBpm() {
	local file="$1"
	local ext="${file##*.}"
	declare -l ext # convert to lowercase
	{ case "$ext" in
		'mp3')	mid3v2 -l "$file" ;;
		'ogg')	vorbiscomment -l "$file" ;;
		'flac')	metaflac --export-tags-to=- "$file" ;;
	esac ; } | fgrep 'BPM=' -a | cut -d'=' -f2
}

# @param string file
# @param int BPM value
function setBpm() {
	local file="$1"
	local bpm="${2%%.*}"
	local ext="${file##*.}"
	declare -l ext # convert to lowercase
	case "$ext" in
		'mp3')	mid3v2 --TBPM "$bpm" "$file" ;;
		'ogg')	vorbiscomment -a -t "BPM=$bpm" "$file" ;;
		'flac')	metaflac --set-tag="BPM=$bpm" "$file"
			mid3v2 --TBPM "$bpm" "$file" # Need to store to ID3 as well :(
		;;
	esac
}

# @param string file
# @returns int BPM value
function computeBpm() {
	local file="$1"
	local m_opt=""
	[ ! -z "$m" ] && m_opt="-m $m"
	local x_opt=""
	[ ! -z "$x" ] && x_opt="-x $x"
	local row=$(bpm-tag -fn $m_opt $x_opt "$file" 2>&1 | fgrep "$file")
	echo $(echo "$row" \
		| sed -r 's/.+ ([0-9]+\.[0-9]{3}) BPM/\1/' \
		| awk '{printf("%.0f\n", $1)}')
}

# @param string file
# @param int file number
# @param int BPM from file list given by --import option
function oneThread() {
	local file="$1"
	local filenumber="$2"
	local bpm_hard="$3"
	local bpm_old=$(getBpm "$file")
	[ -z "$bpm_old" ] && bpm_old="NONE"
	if [ "$e" ] ; then # only show existing
		myEcho "$filenumber/$NUMFILES${SEP}$bpm_old${SEP}$file"
	else # compute new one
		if [ "$bpm_hard" ] ; then
			local bpm_new="$bpm_hard"
		else
			local bpm_new=$(computeBpm "$file")
		fi
		[ "$w" ] && { # write new one
			if [[ ! ( ("$bpm_old" != "NONE") && ( -z "$f" ) ) ]] ; then
				setBpm "$file" "$bpm_new"
			else
				[ "$v" ] && myEcho "Non-empty old BPM value, skipping ..."
			fi
		}
		myEcho "$filenumber/$NUMFILES${SEP}$bpm_old${SEP}$bpm_new${SEP}$file"
	fi
}

function myEcho() {
	[ "$o" ] && echo -e "$1" >> "$o"
	echo -e "$1"
}


# ================================== OPTIONS ==================================

eval set -- $(getopt -n $0 -o "-i:n:o:l:t:ewfm:x:vch" \
	-l "import:,input:,output:,list-save:,type:,existing-only,write,force,min:,max:,verbose,csv-friendly,help" -- "$@")

declare i n o l t e w f m x v c h
declare -a INPUTFILES
declare -a INPUTTYPES
while [ $# -gt 0 ] ; do
	case "$1" in
		-i|--import)				shift ; i="$1" ; shift ;;
		-n|--input)					shift ; n="$1" ; shift ;;
		-o|--output)				shift ; o="$1" ; shift ;;
		-l|--list-save)			shift ; l="$1" ; shift ;;
		-t|--type)					shift ; INPUTTYPES=("${INPUTTYPES[@]}" "$1") ; shift ;;
		-e|--existing-only)	e=1 ; shift ;;
		-w|--write)					w=1 ; shift ;;
		-f|--force)					f=1 ; shift ;;
		-m|--min)						shift ; m="$1" ; shift ;;
		-x|--max)						shift ; x="$1" ; shift ;;
		-v|--verbose)				v=1 ; shift ;;
		-c|--csv-friendly)	c=1 ; shift ;;
		-h|--help)					h=1 ; shift ;;
		--)									shift ;;
		-*)									echo "bad option '$1'" ; exit 1 ;; #FIXME why this exit isn't fired?
		*)									INPUTFILES=("${INPUTFILES[@]}" "$1") ; shift ;;
	esac
done


# ================================= DEFAULTS ==================================

#NOTE Remove what requisities you don't need but don't try to use them after!
#         always  mp3/flac     ogg       flac
REQUIRES="bpm-tag mid3v2 vorbiscomment metaflac"
which $REQUIRES > /dev/null || { myEcho "These binaries are required: $REQUIRES" >&2 ; exit 1; }

[ "$h" ] && {
	help
	exit 0
}

[[ $m && $x && ( $m -ge $x ) ]] && {
	myEcho "Minimal BPM can't be bigger than NOR same as maximal BPM!"
	exit 1
}
[[ "$i" && "$n" ]] && {
	echo "You cannot specify both -i and -n options!"
	exit 1
}
[[ "$i" && ( "$m" || "$x" ) ]] && {
	echo "You cannot use -m nor -x option with -i option!"
	exit 1
}
[ "$e" ] && {
	[[ "$w" || "$f" ]] && {
		echo "With -e option you don't have any value to write!"
		exit 1
	}
	[[ "$m" || "$x" ]] && {
		echo "With -e option you don't have any value to count!"
		exit 1
	}
}

for file in "$o" "$l" ; do 
	if [ -f "$file" ] ; then
		while true ; do
			read -n1 -p "Do you want to overwrite existing file ${file}? (Y/n): " key
			case "$key" in
				y|Y|"")	echo "" > "$file" ; break ;;
				n|N)		exit 0 ;;
			esac
			echo ""
		done
		echo ""
	fi
done

[ ${#INPUTTYPES} -eq 0 ] && INPUTTYPES=("mp3")

NUMCPU="$(grep ^processor /proc/cpuinfo | wc -l)"
LASTPID=0
TYPESALLOWED=("mp3" "ogg" "flac")
declare -A BPMIMPORT # array of BPMs from --import file, keys are file names

for type in "${INPUTTYPES[@]}" ; do
	[[ $(inArray $type TYPESALLOWED[@]) -eq 1 ]] && {
		myEcho "Filetype $type is not one of allowed types (${TYPESALLOWED[@]})!"
		exit 1
	}
done

### here are three ways how to pass files to the script...
if [ "$i" ] ; then # just parse given file list and set BPM to listed files
	if [ -f "$i" ] ; then
		# myEcho "Setting BPM tags from given file ..."
		while read row ; do
			bpm="${row%%;*}"
			file="${row#*;}"
			ext="${file##*.}"
			if [ -f "$file" ] ; then
				if [ $(inArray $ext INPUTTYPES[@]) -eq 0 ] ; then 
					FILES=("${FILES[@]}" "$file")
					BPMIMPORT["$file"]="$bpm"
				else
					myEcho "Skipping file on row $rownumber (unwanted filetype) ... $file"
				fi
			else
				myEcho "Skipping non-existing file $file"
			fi
		done < "$i"
	else
		myEcho "Given import file does not exists!"
		exit 1
	fi
elif [ "$n" ] ; then # get files from file list
	if [ -f "$n" ] ; then
		rownumber=1
		while read file ; do
			if [ -f $file ] ; then
				ext="${file##*.}"
				if [ $(inArray $ext INPUTTYPES[@]) -eq 0 ] ; then 
					FILES=("${FILES[@]}" "$file")
				else
					myEcho "Skipping file on row $rownumber (unwanted filetype) ... $file"
				fi
			else
				myEcho "Skipping file on row $rownumber (non-existing) ... $file"
			fi
			let rownumber++
		done < "$n"
		unset rownumber
	else
		myEcho "Given input file $n does not exists!"
		exit 1
	fi
else # get files from given parameters
	[ ${#INPUTFILES} -eq 0 ] && INPUTFILES=`pwd`
	for file in "${INPUTFILES[@]}" ; do
		[ ! -e "$file" ] && {
			myEcho "File or directory $file does not exist!"
			exit 1
		}
	done
	impl_types=`implode "|" INPUTTYPES[@]`
	while read file ; do
		echo -ne "Creating list of files ... (${#FILES[@]}) ${file}\033[0K"\\r
		FILES=("${FILES[@]}" "$file")
	done < <(find "${INPUTFILES[@]}" -type f -regextype posix-awk -iregex ".*\.($impl_types)")
	echo -e "Counted ${#FILES[@]} files\033[0K"\\r
fi

[ "$l" ] && printf '%s\n' "${FILES[@]}" > "$l"

NUMFILES=${#FILES[@]}
FILENUMBER=1

[ $NUMFILES -eq 0 ] && {
	myEcho "There are no ${INPUTTYPES[@]} files in given files/paths."
	exit 1
}

declare SEP=" "
[ "$c" ] && SEP=";"


# =============================== MAIN SECTION ================================

if [ "$e" ] ; then # what heading to show
	myEcho "num${SEP}old${SEP}filename"
else
	myEcho "num${SEP}old${SEP}new${SEP}filename"
fi

for file in "${FILES[@]}" ; do
	[ `jobs -p | wc -l` -ge $NUMCPU ] && wait
	[ "$v" ] && myEcho "Parsing (${FILENUMBER}/${NUMFILES})\t$file ..."
	oneThread "$file" "$FILENUMBER" "${BPMIMPORT[$file]}" &
	LASTPID="$!"
	let FILENUMBER++
done

[ "$v" ] && myEcho "Waiting for last process ..."
wait $LASTPID
[ "$v" ] && myEcho \\n"DONE"

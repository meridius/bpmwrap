#!/bin/bash


# ================================= FUNCTIONS =================================

function help() {
	less <<< 'BPMWRAP

Description:   
	Wrapper for bpm-tag and several audio tagging utilities for BPM 
	(beats per minute) processing.
	Default behaviour is to look through working directory for *.mp3 files 
	and compute and print their BPM in the following manner: 
		[current (if any)] [computed] [filename]

Usage:
	bpmwrap [options] [directory or filenames]

Options:
	-i, --import file
		Use this option to set BPM tag for all files in given file instead of 
		computing it. Expected format of every row is BPM number and absolute path 
		to filename separated by semicolon like so:
			145;/home/trinity/music/Apocalyptica/07 beyond time.mp3
	-o, --output file
		Save output also to a file.
	-t, --type
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
# @returns int file number
function oneThread() {
	local file="$1"
	local filenumber="$2"
	local bpm_old=$(getBpm "$file")
	[ -z "$bpm_old" ] && bpm_old="NONE"
	if [ "$e" ] ; then # only show existing
		myEcho "$filenumber/$NUMFILES${SEP}$bpm_old${SEP}$file"
	else # compute new one
		local bpm_new=$(computeBpm "$file")
		[ "$w" ] && { # write new one
			if [[ ! ( ("$bpm_old" != "NONE") && ( -z "$f" ) ) ]] ; then
				setBpm "$file" "$bpm_new"
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

eval set -- $(getopt -n $0 -o "-i:o:t:ewfm:x:vch" \
	-l "import:,output:,type,existing-only,write,force,min:,max:,verbose,csv-friendly,help" -- "$@")

declare i o t e w f m x v c h
declare -a INPUTFILES
declare -a INPUTTYPES
while [ $# -gt 0 ] ; do
	case "$1" in
		-i|--import)				shift ; i="$1" ; shift ;;
		-o|--output)				shift ; o="$1" ; shift ;;
		-t|--type)					shift ; INPUTTYPES=("${INPUTTYPES[@]}" "$1") ; shift ;;
		-e|--existing-only)	e=1 ; shift ;;
		-w|--write)					w=1 ; shift ;;
		-f|--force)					f=1 ; shift ;;
		-m|--min)						shift ; m="$1" ; shift ;;
		-x|--max)						shift ; x="$1" ; shift ;;
		-v|--verbose)				v=1 ; shift ;;
		-c|--csv-friendly)	c=1 ; shift ;;
		-h|--help)					h=1 ; shift ;;
		--) shift ;;
		-*) echo "bad option '$1'" ; exit 1 ;; #FIXME why this exit isn't fired?
		*) INPUTFILES=("${INPUTFILES[@]}" "$1") ; shift ;;
	esac
done


# ================================= DEFAULTS ==================================

if [ ${#INPUTFILES} -eq 0 ] ; then
	INPUTFILES=`pwd`
fi

if [ ${#INPUTTYPES} -eq 0 ] ; then
	INPUTTYPES=("mp3")
fi

declare SEP=" "
[ "$c" ] && SEP=";"

# ======================= VARIABLES AND ERROR CONTROLL ========================

TYPESALLOWED=("mp3" "ogg" "flac")

[[ $m && $x && ( $m -ge $x ) ]] && {
	myEcho "Minimal BPM can't be bigger than NOR same as maximal BPM!"
	exit 1
}

for file in "${INPUTFILES[@]}" ; do
	[ ! -e "$file" ] && {
		myEcho "File or directory $file does not exist!"
		exit 1
	}
done

for type in "${INPUTTYPES[@]}" ; do
	result=$(inArray $type TYPESALLOWED[@])
	[[ $result -eq 1 ]] && {
		myEcho "Filetype $type is not one of allowed types (${TYPESALLOWED[@]})!"
		exit 1
	}
done

NUMCPU="$(grep ^processor /proc/cpuinfo | wc -l)"
LASTPID=0
impl_types=`implode "|" INPUTTYPES[@]`
while read file ; do
	FILES=("${FILES[@]}" "$file")
done < <(find "${INPUTFILES[@]}" -type f -regextype posix-awk -iregex ".*\.($impl_types)")
NUMFILES=${#FILES[@]}
FILENUMBER=1


# =============================== MAIN SECTION ================================

[ "$i" ] && { # just parse given file and set BPM to listed files
	myEcho "Setting BPM tags from given file ..."
	while read row ; do
		bpm=${row%%;*}
		file=${row#*;}
		myEcho "Setting $bpm BPM to $file ..."
		setBpm "$file" "$bpm"
	done < "$i"
	exit 0
}

[ "$h" ] && {
	help
	exit 0
}

[ $NUMFILES -eq 0 ] && {
	myEcho "There are no ${INPUTTYPES[@]} files in ${INPUTFILES[@]}."
	myEcho "Nothing to do."
	exit 0
}

if [ "$e" ] ; then # what heading to show
	myEcho "num${SEP}old${SEP}filename"
else
	myEcho "num${SEP}old${SEP}new${SEP}filename"
fi

for file in "${FILES[@]}" ; do
	[ `jobs -p | wc -l` -ge $NUMCPU ] && wait
	[ "$v" ] && myEcho "Parsing (${FILENUMBER}/${NUMFILES})\t$file ..."
	oneThread "$file" "$FILENUMBER" &
	LASTPID="$!"
	let FILENUMBER++
done

[ "$v" ] && myEcho "Waiting for last process ..."
wait $LASTPID
[ "$v" ] && myEcho \\n"DONE"

bpmwrap - BPM tagging made easier
=======

## Description:   
This BASH script is a wrapper for bpm-tag utility of [bpm-tools](http://www.pogo.org.uk/~mark/bpm-tools/) and several audio tagging utilities. The purpose is to make BPM (beats per minute) tagging as easy as possible.  
Default behaviour is to look through working directory for *.mp3 files and compute and print their BPM in the following manner:  
```
[current (if any)] [computed] [filename]
```

## Usage:
```
bpmwrap [options] [directory or filenames]
```

## Options:
- -i, --import file  
	Use this option to set BPM tag for all files in given file instead of computing it. Expected format of every row is BPM number and absolute path to filename separated by semicolon like so:
```
145;/home/trinity/music/Apocalyptica/07 beyond time.mp3
```
- -o, --output file  
	Save output also to a file.
- -t, --type  
	Extension of file type to work with. Defaults to mp3. Can be specified multiple times for more filetypes. Currently supported are mp3 ogg flac.
- -e, --existing-only  
	Only show BPM for files that have it. Do NOT compute new one.
- -w, --write  
	Write computed BPM to audio file but do NOT overwrite existing value.
- -f, --force  
	Write computed BPM to audio file even if it already has one. Aplicable only with --write option.
- -m, --min minbpm  
	Set minimal BPM to look for when computing. Defaults to bpm-tag minimum 84.
- -x, --max maxbpm  
	Set maximal BPM to look for when computing. Defaults to bpm-tag maximum 146.
- -v, --verbose  
	Show "progress" messages.
- -c, --csv-friendly  
	Use semicolon (;) instead of space to separate output columns.
- -h, --help  
	Show this help.


## Thank you
This script is based on kolypto's work published at http://superuser.com/a/129157/137326

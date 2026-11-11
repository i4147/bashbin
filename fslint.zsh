#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
script_dir=$(dirname "$0")
script_dir=$(readlink -f "$script_dir")
. "$script_dir"/supprt/fslver
Usage() {
	ProgName=$(basename "$0")
	echo "File system lint.
A collection of utilities to find lint on a filesystem.
To get more info on each utility run 'util --help'.
findup -- find DUPlicate files
findnl -- find Name Lint (problems with filenames)
findu8 -- find filenames with invalid utf8 encoding
findbl -- find Bad Links (various problems with symlinks)
findsn -- find Same Name (problems with clashing names)
finded -- find Empty Directories
findid -- find files with dead user IDs
findns -- find Non Stripped executables
findrs -- find Redundant Whitespace in files
findtf -- find Temporary Files
findul -- find possibly Unused Libraries
zipdir -- Reclaim wasted space in ext2 directory entries"
	exit
}
for arg; do
	case "$arg" in
	-h | --help | -help)
		Usage
		;;
	-v | --version)
		Version
		;;
	esac
done
echo "-----------------------------------file name lint"
"$script_dir"/findnl "$@"
echo "-------------------------------Invalid utf8 names"
"$script_dir"/findu8 "$@"
echo "-----------------------------------file case lint"
"$script_dir"/findsn -c "$@"
echo "----------------------------------DUPlicate files"
"$script_dir"/findup "$@"
echo "-----------------------------------Dangling links"
"$script_dir"/findbl "$@"
echo "--------------------redundant characters in links"
"$script_dir"/findbl -n "$@"
echo "------------------------------------suspect links"
"$script_dir"/findbl -s "$@"
echo "--------------------------------Empty Directories"
"$script_dir"/finded "$@"
echo "----------------------------------Temporary Files"
"$script_dir"/findtf "$@"
echo "----------------------duplicate/conflicting Names"
if [ "$1" = "/" ]; then
	"$script_dir"/findsn
else
	"$script_dir"/findsn "$@"
fi
echo "------------------------------------------Bad ids"
"$script_dir"/findid "$@"
echo "-------------------------Non Stripped executables"
if [ "$1" = "/" ]; then
	"$script_dir"/findns
else
	"$script_dir"/findns "$@"
fi

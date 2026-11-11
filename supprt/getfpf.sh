#!/data/data/com.termux/files/usr/bin/bash
num_files=0
files=
switches=
onfindswitches=false
forcefullpath=false
eval set -- "$@"
for arg in "$@"; do
	case "$arg" in
	-r)
		switches="$switches -maxdepth 1"
		;;
	-f)
		forcefullpath=true
		;;
	-* | \( | \) | !)
		switches="$switches '$arg'"
		onfindswitches=true
		;;
	*)
		if [ "$onfindswitches" = "true" ]; then
			switches="$switches $(shell_quote "$arg")"
		else
			num_files=$(expr $num_files + 1)
			if [ -z "$files" ]; then
				files="$(shell_quote "$arg")"
			else
				files="$files $(shell_quote "$arg")"
			fi
		fi
		;;
	esac
done
if [ $num_files -gt 1 ]; then
	FPF="%p"
	findArgs="$files $switches"
else
	if [ $forcefullpath = "true" ]; then
		findArgs="$files $switches"
		FPF="%p"
	else
		findArgs="$switches"
		FPF="%P"
		if [ $num_files -eq 1 ]; then
			findArgs="$files $switches"
			eval files=$files
			if [ -d "$files" ]; then
				cd "$files"
				findArgs="$switches"
			else
				FPF="%p"
			fi
		fi
	fi
fi
eval set -- "$findArgs"

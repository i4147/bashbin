#!/data/data/com.termux/files/usr/bin/bash
if [ "$1" = "-g" ]; then
	vim="gvim"
	shift
else
	vim="vim"
fi
if [ "$#" = "1" ]; then
	if [ -d "$1" ]; then
		xdg-open "$1"
		exit
	fi
fi
if ! $vim -h >/dev/null 2>&1; then
	cat >/dev/null
	echo "Error: please install $vim to view whitespace" >&2
	exit
fi
$vim -R \
	+'highlight RedundantSpaces term=standout ctermbg=red guibg=red' \
	+'match RedundantSpaces /\s\+$\| \+\ze\t/' \
	+'set listchars=tab:>-,trail:.,extends:>' \
	+'set list!' "$@"

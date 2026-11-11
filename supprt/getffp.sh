#!/data/data/com.termux/files/usr/bin/bash
if [ "x$1" != "x-justPATH" ]; then
	PERMPATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:
	/usr/X11R6/bin:/usr/TeX/bin:/usr/tex/bin:/usr/games:/usr/local/games:"
fi
FINDDIRS=$(echo $PERMPATH$PATH | tr : '\n' | sed -e '/^$/d')
find $FINDDIRS -type d -maxdepth 0 -follow -printf "%p\t%i\n" 2>/dev/null |
	sort -k2,2n -u |
	cut -f1 |
	tr '\n' : |
	sed 's|:|/ |g' |
	tr -s /
echo "-maxdepth 1"

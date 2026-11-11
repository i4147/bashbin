#!/data/data/com.termux/files/usr/bin/bash
if [ "x$1" != "x-justPATH" ]; then
	PERMPATH="/lib /usr/lib /usr/local/lib"
fi
CURRPATH=$(cat /etc/ld.so.conf)
LIB_PATH=$(echo $LD_LIBRARY_PATH | tr : '\n' | sed -e '/^$/d')
find $PERMPATH $CURRPATH $LIB_PATH -type d -maxdepth 0 -follow \
	-printf "%p\t%i\n" 2>/dev/null |
	sort -k2,2n -u |
	cut -f1 |
	tr '\n' : |
	sed 's|:|/ |g' |
	tr -s /
echo "-maxdepth 1"

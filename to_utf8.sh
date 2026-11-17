#!/data/data/com.termux/files/usr/bin/bash
# to_UTF8.sh
#   script to convert UTF-16 from Visual Studio to UTF-8
#
#   usage:  to_UTF8.sh filename
#   or      to_UTF8.sh filename 2>/dev/null      to ignore output
#
#       if file is UTF8 to begin with, no change is made
#       if file is UTF-16, original file is renamed to (original_name).utf16
#           converted to UTF-8, and the resulting file has the same name 
#           as the original file.
#
#   CAVEAT:  will not handle filenames with spaces!
#
#   Author:     Ian Scott-Fleming
#               Texas Tech Dept. of Elec & Computer Engineering


fn=$1

enc=$(file -I $fn | grep 16)
if [[ $enc ]]
then
    echo converting code from UTF-16 to UTF-8           1>&2
    echo "iconv -f UTF-16 -t UTF-8  $fn > $fn.utf8"     1>&2
          iconv -f UTF-16 -t UTF-8 $fn  > $fn.utf8
    echo "mv $fn $fn.utf16"                             1>&2
          mv $fn $fn.utf16
    echo "mv $fn.utf8 $fn"                              1>&2
          mv $fn.utf8 $fn
else
    echo $fn is not UTF-16                              1>&2
fi

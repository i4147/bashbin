#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
scriptversion=2021-02-27.01
if test -z "$PYTHON"; then
	PYTHON=python
fi
me=py-compile
usage_error() {
	echo "$me: $*" >&2
	echo "Try '$me --help' for more information." >&2
	exit 1
}
basedir=
destdir=
while test $# -ne 0; do
	case "$1" in
	--basedir)
		if test $# -lt 2; then
			usage_error "option '--basedir' requires an argument"
		else
			basedir=$2
		fi
		shift
		;;
	--destdir)
		if test $# -lt 2; then
			usage_error "option '--destdir' requires an argument"
		else
			destdir=$2
		fi
		shift
		;;
	-h | --help)
		cat <<\EOF
Usage: py-compile [--help] [--version] [--basedir DIR] [--destdir DIR] FILES..."
Byte compile some python scripts FILES.  Use --destdir to specify any
leading directory path to the FILES that you don't want to include in the
byte compiled file.  Specify --basedir for any additional path information you
do want to be shown in the byte compiled file.
Example:
  py-compile --destdir /tmp/pkg-root --basedir /usr/share/test test.py test2.py
Report bugs to <bug-automake@gnu.org>.
EOF
		exit $?
		;;
	-v | --version)
		echo "$me $scriptversion"
		exit $?
		;;
	--)
		shift
		break
		;;
	-*)
		usage_error "unrecognized option '$1'"
		;;
	*)
		break
		;;
	esac
	shift
done
files=$*
if test -z "$files"; then
	usage_error "no files given"
fi
if test -z "$basedir"; then
	pathtrans="path = file"
else
	pathtrans="path = os.path.join('$basedir', file)"
fi
if test -z "$destdir"; then
	filetrans="filepath = path"
else
	filetrans="filepath = os.path.normpath('$destdir' + os.sep + path)"
fi
python_major=$($PYTHON -V 2>&1 | sed -e 's/.* //;s/\..*$//;1q')
if test -z "$python_major"; then
	echo "$me: could not determine $PYTHON major version, guessing 3" >&2
	python_major=3
fi
if test "$python_major" -le 2; then
	import_lib=imp
	import_test="hasattr(imp, 'get_tag')"
	import_call=imp.cache_from_source
else
	import_lib=importlib
	import_test="hasattr(sys.implementation, 'cache_tag')"
	import_call=importlib.util.cache_from_source
fi
$PYTHON -c "
import sys, os, py_compile, $import_lib
files = '''$files'''
sys.stdout.write('Byte-compiling python modules...\n')
for file in files.split():
    $pathtrans
    $filetrans
    if not os.path.exists(filepath) or not (len(filepath) >= 3
                                            and filepath[-3:] == '.py'):
	    continue
    sys.stdout.write(file)
    sys.stdout.flush()
    if $import_test:
        py_compile.compile(filepath, $import_call(filepath), path)
    else:
        py_compile.compile(filepath, filepath + 'c', path)
sys.stdout.write('\n')" || exit $?
$PYTHON -O -c "
import sys, os, py_compile, $import_lib
# pypy does not use .pyo optimization
if hasattr(sys, 'pypy_translation_info') and sys.hexversion < 0x03050000:
    sys.exit(0)
files = '''$files'''
sys.stdout.write('Byte-compiling python modules (optimized versions) ...\n')
for file in files.split():
    $pathtrans
    $filetrans
    if not os.path.exists(filepath) or not (len(filepath) >= 3
                                            and filepath[-3:] == '.py'):
	    continue
    sys.stdout.write(file)
    sys.stdout.flush()
    if $import_test:
        py_compile.compile(filepath, $import_call(filepath), path)
    else:
        py_compile.compile(filepath, filepath + 'o', path)
sys.stdout.write('\n')" 2>/dev/null || :
$PYTHON -OO -c "
import sys, os, py_compile, $import_lib
# python<3.5 does not have split files for -O and -OO
if sys.hexversion < 0x03050000:
    sys.exit(0)
files = '''$files'''
sys.stdout.write('Byte-compiling python modules (optimized versions) ...\n')
for file in files.split():
    $pathtrans
    $filetrans
    if not os.path.exists(filepath) or not (len(filepath) >= 3
                                            and filepath[-3:] == '.py'):
	    continue
    sys.stdout.write(file)
    sys.stdout.flush()
    if $import_test:
        py_compile.compile(filepath, $import_call(filepath), path)
    else:
        py_compile.compile(filepath, filepath + 'o', path)
sys.stdout.write('\n')" 2>/dev/null || exit $?

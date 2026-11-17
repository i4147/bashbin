#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH

# ${(%):-%N} is the Zsh equivalent of Bash's ${BASH_SOURCE[0]}: it expands to
# the path of this script even when the script is sourced rather than run.
SCRIPT_DIR="$( cd "$( dirname "${(%):-%N}" )" >/dev/null && pwd )"

[[ ! "${OPENCV_QUIET}" ]] && ( echo "Setting vars for OpenCV 4.12.0" )
export LD_LIBRARY_PATH="$SCRIPT_DIR/../lib:$LD_LIBRARY_PATH"

if [[ ! "$OPENCV_SKIP_PYTHON" ]]; then
  PYTHONPATH_OPENCV="$SCRIPT_DIR/../lib/python3.12/site-packages"
  [[ ! "${OPENCV_QUIET}" ]] && ( echo "Append PYTHONPATH: ${PYTHONPATH_OPENCV}" )
  export PYTHONPATH="${PYTHONPATH_OPENCV}:$PYTHONPATH"
fi

# Don't exec in "sourced" mode
if [[ "${(%):-%N}" == "${0}" ]]; then
  if [[ $# -ne 0 ]]; then
    [[ ! "${OPENCV_QUIET}" && "${OPENCV_VERBOSE}" ]] && ( echo "Executing: $*" )
    exec "$@"
  fi
fi

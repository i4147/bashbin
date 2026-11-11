#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
export CC="clang"
export CXX="clang++"
export AR="ar"
export RANLIB="ranlib"
export LD="ld"
export OPT_DIR=$PREFIX/opt
export CFLAGS="-I${PREFIX}/include \
               -I${PREFIX}/opt/nodejs-12/include \
               -fPIC -fPIE"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L${PREFIX}/lib -fPIE -pie"
export CFLAGS="$CFLAGS -O2"
export CXXFLAGS="$CXXFLAGS -O2"
export PYTHON_CFLAGS="$CFLAGS"
export PYTHON_LDFLAGS="$LDFLAGS"
export PIP_BUILD_ISOLATION=0
export CC=clang
export CXX=clang++
export LD=ld.lld
export LDFLAGS="-fuse-ld=lld"
export CFLAGS="-O2"
export CXXFLAGS="-O2"

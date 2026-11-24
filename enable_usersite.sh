#!/data/data/com.termux/files/usr/bin/sh
echo "$PYTHONNOUSERSITE"
unset PYTHONNOUSERSITE
python -c 'import site; print(site.ENABLE_USER_SITE, site.getusersitepackages())'

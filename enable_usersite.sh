echo "$PYTHONNOUSERSITE"
unset PYTHONNOUSERSITE
python -c 'import site; print(site.ENABLE_USER_SITE, site.getusersitepackages())'

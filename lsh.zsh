#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
fn="$@"
ls -l "$fn" | (
	read perm unknown1 group user size month day tclock fname
	echo $fname $size $month $day $perm
)

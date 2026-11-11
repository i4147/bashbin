#!/data/data/com.termux/files/usr/bin/zsh
setopt SH_WORD_SPLIT GLOB_SUBST
unsetopt NOMATCH
mkdir -p ~/.local/share/nvim/site/parser
ln -sf ~/.local/lib/libtree-sitter-python.so ~/.local/share/nvim/site/parser/python.so
ln -sf ~/.local/lib/libtree-sitter-cpp.so ~/.local/share/nvim/site/parser/cpp.so
ln -sf ~/.local/lib/libtree-sitter-typescript.so ~/.local/share/nvim/site/parser/typescript.so
ln -sf ~/.local/lib/libtree-sitter-tsx.so ~/.local/share/nvim/site/parser/tsx.so

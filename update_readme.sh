#!/usr/bin/env sh

space -m autodoc /export/ -- Spacefile.bash && \
    mv Spacefile.bash_README README.md && printf "README.md has been overwritten\n"

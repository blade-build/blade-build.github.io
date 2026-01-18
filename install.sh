#!/bin/bash

set -e

mkdir -p ~/.cache

if [[ -d ~/.cache/blade-build ]]; then
    git -C ~/.cache/blade-build pull
else
    git clone https://github.com/blade-build/blade-build ~/.cache/blade-build
fi

cd ~/.cache/blade-build
./install


#!/bin/bash
# Build the whole fuzzing image
source conf.sh
docker build -t $IMAGE . | grep --line-buffered -v objtool | tee /tmp/build_out

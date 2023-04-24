#!/bin/bash
# Minimize the fuzzing corpus
source conf.sh
docker run $DFLAGS "/mincorp_internal.sh; bash"

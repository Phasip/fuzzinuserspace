#!/bin/bash
# Run afl-whatsup in the container
source conf.sh
docker run $DFLAGS "afl-whatsup -s /$SHARED/$OUTPUTS"

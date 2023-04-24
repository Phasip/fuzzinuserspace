#!/bin/bash
source /conf.sh
mkdir /$SHARED/clean_corp
# afl-cmin doesn't like us using /tmp. This is run in a docker container so lets just create mtmp...
mkdir -p /mtmp/full_corp
# Leave a hint for anyone confused.
touch /mtmp/CREATED_BY_mincorp_internal.sh_SHOULD_BE_IN_A_DOCKER_CONTAINER
rsync -r /$SHARED/$INPUTS/ /mtmp/full_corp
rsync -r /$SHARED/$OUTPUTS/*/queue/ /mtmp/full_corp
bash -c "$AFLFLAGS afl-cmin -i /mtmp/full_corp -o /$SHARED/clean_corp $CMIN"

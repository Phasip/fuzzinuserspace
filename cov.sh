#!/bin/bash
# Get coverage
source conf.sh
docker run $DFLAGS "$PREP_CMD; /cov_internal.sh; bash"

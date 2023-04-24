#!/bin/bash
source /conf.sh
AP="/$SHARED/$INPUTS /$SHARED/$OUTPUTS/*/queue/ /$SHARED/$OUTPUTS/*/crashes/ /$SHARED/$OUTPUTS/*/hangs/"
find $AP -type f -exec /bin/sh -c "$COVBIN $DEBUGPRE {} $DEBUGPOST" \;
#lcov --no-external --capture --initial --directory /usr/local/src/libreoffice --output-file /tmp/libreoffice_base.info
lcov --capture --directory $COVSRC --output-file /tmp/lcov.info
genhtml --prefix $COVSRC --ignore-errors source /tmp/lcov.info --legend --title "Cov internal" --output-directory=/$SHARED/lcov_output/

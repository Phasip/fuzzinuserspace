#!/bin/bash
# Run crashes and output some data
source /conf.sh
# 1. Fix invocation in find command
# 2. Fix invocation in set args of gdb
find /$SHARED/$OUTPUTS -wholename \*crashes/id\* -exec /bin/sh -c "$DEBUGBIN $DEBUGPRE {} $DEBUGPOST"' 1>/dev/null 2>/tmpfs/out; echo "{}:$?"' \; | grep -v ':0$' | rev | cut -d: -f2- | rev | tee /tmp/crashing_files
for f in $(cat /tmp/crashing_files); do 
	gdb "$DEBUGBIN" -ex 'set pagination off' -ex 'set confirm off' -ex "set args $DEBUGPRE $f $DEBUGPOST" -ex run -ex 'bt 8' -ex quit 2>&1 | grep -E ') at |program: |fuzzing.debug: | signal |^#[0-9]|) from '; 
done | tee /$SHARED/errors

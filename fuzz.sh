#!/bin/bash
# Start the fuzzing
set -e -x
source conf.sh
#--Launch all the runners-- 
screen -d -m -S leader /usr/bin/docker run $DFLAGS "$PREP_CMD; $AFLFLAGS afl-fuzz -b1 $AFLARGS -M $ARCH-leader $LEADER; exec bash"
for i in $(seq 2 5 $(nproc)); do sleep 1; screen -d -m -S minionA$i /usr/bin/docker run $DFLAGS "$PREP_CMD; $AFLFLAGS afl-fuzz -b$i $AFLARGS -S $ARCH-minion-a-$i $MINIONA; bash"; done
for i in $(seq 3 5 $(nproc)); do sleep 1; screen -d -m -S minionR$i /usr/bin/docker run $DFLAGS "$PREP_CMD; $AFLFLAGS AFL_CUSTOM_MUTATOR_LIBRARY='/AFLplusplus/custom_mutators/radamsa/radamsa-mutator.so;/AFLplusplus/custom_mutators/libfuzzer/libfuzzer-mutator.so' afl-fuzz -b$i $AFLARGS -S $ARCH-minion-r-$i $MINIONRADAMSA; bash"; done
for i in $(seq 4 5 $(nproc)); do sleep 1; screen -d -m -S minionB$i /usr/bin/docker run $DFLAGS "$PREP_CMD; $AFLFLAGS afl-fuzz -b$i $AFLARGS -S $ARCH-minion-b-$i $MINIONB; bash"; done
for i in $(seq 5 5 $(nproc)); do sleep 1; screen -d -m -S minionC$i /usr/bin/docker run $DFLAGS "$PREP_CMD; $AFLFLAGS afl-fuzz -b$i $AFLARGS -S $ARCH-minion-c-$i $MINIONC; bash"; done
for i in $(seq 6 5 $(nproc)); do sleep 1; screen -d -m -S minionD$i /usr/bin/docker run $DFLAGS "$PREP_CMD; $AFLFLAGS afl-fuzz -b$i $AFLARGS -S $ARCH-minion-d-$i $MINIOND; bash"; done

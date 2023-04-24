# This is a ugly hack because I don't want to write pretty scripts
# If we need to run a command in the container before starting fuzzing
PREP_CMD="true"
#PREP_CMD="cp -r /tmpfs_init/* /tmpfs/"

SHARED="/fuzzing"
INPUTS="inputs"
OUTPUTS="outputs"
IMAGE="fuzzanger"

# NOTE: If DEBUG doesn't take the file as an argument, you need to fix crashes_internal.sh to reflect how to give input
DEBUGBIN="/targets/clean"
COVBIN="/targets/gcov"
COVSRC="/src/gcov/linux"

# COV also uses these
DEBUGPRE=""
DEBUGPOST=""

LEADER="-- /targets/afl @@"
CMIN="$LEADER"
MINIONA="-- /targets/afl @@"
MINIONRADAMSA="-- /targets/afl @@"
MINIONB="-D -- /targets/afl @@"
MINIONC="-p exploit -- /targets/afl @@"
MINIOND="-p rare -- /targets/afl @@"

# You shouldn't have to change anything below here
DFLAGS="-v $(pwd)$SHARED:$SHARED --net=host --pid=host --ipc=host --uts=host --log-driver=none --rm --privileged -it --tmpfs /tmpfs --tmpfs /usr/local/var/run --user=root $IMAGE"
AFLFLAGS="PYTHONPATH=/ AFL_MAP_SIZE=328792 AFL_TMPDIR=/tmpfs AFL_AUTORESUME=1 "
ARCH="Box1"
AFLARGS="-i $SHARED/$INPUTS -o $SHARED/$OUTPUTS -t 2000"

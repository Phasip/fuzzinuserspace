# What
Docker system and tooling to compile & fuzz parts of the kernel in user-space.
1. It compiles the all parts of the kernel for linking into regular user-space programs
2. It builds three versions of your fuzz-harness, one "regular" one with afl and one with coverage
3. It provides scripts for starting the fuzzing on multiple cores
# Usage
## Requirements: Not a complete list, things I remember that are required.
```
apt install graphviz docker.io python3 python3-pip
pip3 install angr angr-utils
```
## Running
```
./build.sh
./fuzz.sh
watch -n 60 ./info.sh
```
# Files
### build.sh
Build the docker image for fuzzing. Run once you configured everything.

### compile.sh
Compile kernel & fuzz harness, modify to fit your harness. Will be run by Dockerfile.

### conf.sh
Configs for scripts and build

### cov_internal.sh
Part of coverage script placed within Docker container, no need to run manually

### cov.sh
Analyze fuzzing coverage

### crashes_internal.sh
Analyze found crashes, needs to be run from within docker container. Unknown if it is working.

### Dockerfile
Base for docker image, starts with aflplusplus image, builds kernel three times

### fuzz.sh
Run docker image and start fuzzing with different configurations of AFL, modify to match your usage of AFL.
Uses all your cores.

### info.sh
Get info about your fuzzing run

### kernel-mocker.c
Mocked functions for the kernel. Add mocked functions to match your target

### kernel.patch
Minor modifications to the kernel code to expose the function targeted for fuzzing. Modify to expose your target

### main.c
Fuzzing harness. Modify to match your target

### mincorp_internal.sh
Internal part of mincorp.sh, no need to run manually

### mincorp.sh
Minimize the fuzzing corpus using afl-cmin

### needed.py
Identifies required functions and .o files for building a binary using the given function in the kernel.

Assumes that we have a source-folder of a compiled kernel (i.e all .o files remainig) named 'linux'
Takes two arguments, the name of the function to start identifying dependencies for and the .o file that contains this function.

Outputs the spec of  a graphviz '.dot' file to the stdout and outputs the required .o files to stderr (and also debug info)
### README.md
This file.

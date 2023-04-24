FROM aflplusplusnew:latest

# Generic
ARG DEBIAN_FRONTEND=noninteractive
RUN sed -i 's/# deb-src/deb-src/g' /etc/apt/sources.list
RUN cd /AFLplusplus/custom_mutators/radamsa/; make
RUN cd /AFLplusplus/custom_mutators/libfuzzer/; make
RUN apt-get update -y && apt-get install -y screen lcov tmux rsync
RUN git clone https://github.com/fekir/afl-extras.git && cp afl-extras/afl-ptmin /usr/local/bin/
ENTRYPOINT ["/bin/bash", "-c"]

# Kernel building & angr
RUN apt-get update -y; apt-get install -y dpkg-dev flex bison libssl-dev libelf-dev bc cpio python3-pip graphviz
RUN pip3 install angr

RUN apt-get install -y libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf debhelper
RUN mkdir -p /src/base && \
    cd /src/base && \
    apt-get source linux-source-5.15.0 && \
    mv linux-5.15.0 linux
ADD main.c /src/base/
ADD needed.py /src/
ADD kernel.patch /src/base/
ADD kernel-mocker.c /src/base/

ADD compile.sh /
RUN chmod +x /compile.sh 
RUN mkdir /targets
RUN COMPILER=afl-cc /compile.sh /src/base /src/afl /targets/afl
RUN COMPILER=gcc CFLAGS="" /compile.sh /src/base /src/clean /targets/clean
RUN COMPILER=gcc FFLAGS="-lgcov" CFLAGS="-fprofile-arcs -ftest-coverage" /compile.sh /src/base /src/gcov /targets/gcov



# Finally, add our config
ADD conf.sh /
ADD crashes_internal.sh /
ADD mincorp_internal.sh /
ADD cov_internal.sh /
RUN chmod +x /conf.sh /crashes_internal.sh /mincorp_internal.sh /cov_internal.sh

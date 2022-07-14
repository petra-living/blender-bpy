FROM nvidia/cuda:11.4.0-devel-ubuntu20.04

ENV DEBIAN_FRONTEND noninteractive

ARG PYTHON_VER_MAJ=3.10
ARG PYTHON_VER=3.10.5

ARG BLENDER_VERSION=3.2

ENV PYTHON_SITE_PACKAGES /usr/local/lib/python$PYTHON_VER_MAJ/site-packages/
ENV WITH_INSTALL_PORTABLE OFF

RUN apt-get update
RUN apt-get -y install \
    build-essential \
    cmake \
    curl \
    git \
    subversion \
    sudo \
    ncdu \
    zlib1g zlib1g-dev

# official Blender deps
RUN apt-get install -y build-essential git subversion cmake libx11-dev libxxf86vm-dev libxcursor-dev libxi-dev libxrandr-dev libxinerama-dev libglew-dev

# install python
WORKDIR /home/tmp/python
ADD https://www.python.org/ftp/python/$PYTHON_VER/Python-$PYTHON_VER.tgz Python.tgz
RUN tar xzf Python.tgz
WORKDIR /home/tmp/python/Python-$PYTHON_VER
RUN ./configure --enable-optimizations
RUN make -j$(nproc) install

#RUN apt-get install -y python3.10

WORKDIR /home/tmp/lib
RUN svn checkout https://svn.blender.org/svnroot/bf-blender/trunk/lib/linux_centos7_x86_64

WORKDIR /home/tmp
RUN git clone https://git.blender.org/blender.git # -b v3.1.2

WORKDIR /home/tmp/blender
RUN git submodule update --init --recursive

#RUN bash ./build_files/build_environment/install_deps.sh

#RUN make update
#RUN make
RUN make bpy

WORKDIR /home/tmp/blender/build_linux_bpy
RUN ls -l
RUN cmake .. \
    -DWITH_CYCLES_CUDA_BINARIES=ON \
    -DCYCLES_CUDA_BINARIES_ARCH=sm_75 \
    -DPYTHON_SITE_PACKAGES=/usr/local/lib/python$PYTHON_VER_MAJ/site-packages/ \
    -DWITH_INSTALL_PORTABLE=OFF \
    -DWITH_PYTHON_INSTALL=OFF \
    -DWITH_PLAYER=OFF \
    -DWITH_PYTHON_MODULE=ON \
    -DWITH_MEM_JEMALLOC=OFF # workaround for some weird TLS import bug
RUN make install -j$(nproc)

# Rebuild python - this is a hack to avoid a long rebuild
RUN apt-get -y install \
    openssl libssl-dev \
    libffi-dev

WORKDIR /home/tmp/python/Python-$PYTHON_VER
RUN ./configure --enable-optimizations
RUN make -j$(nproc) install

# cleanup
RUN rm -rf /home/tmp

WORKDIR /home

# test if it works
RUN python3 -c "import bpy;print(dir(bpy.types));print(bpy.app.version_string);"

CMD bash

#!/bin/bash

#Controlled by environment var CONTRAIL_BUILD_JOBS
# Export CONTRAIL_BUILD_JOBS
export CONTRAIL_BUILD_JOBS=1

# Downloads the package lists from the repositories
apt-get update -y
apt-get install equivs -y

# Set sysctl 
sysctl -w net.core.somaxconn=1024
sysctl -w vm.max_map_count=1048575

# Install all needed dependencies for Opencontrail 
cd src/build/packages/
for d in */ ; do echo "$d"; cd $d; mk-build-deps -t "apt-get -o Debug::pkgProblemResolver=yes -y" -i debian/control; dpkg -i $d*.deb; cd ../ ; done
cd ../../
#gevent
pip install gevent

# Install all needed dependencies for Unittest "scons tests"
apt-get -y install flex bison libboost-python-dev google-mock libgtest-dev liblog4cplus-dev libtbb-dev curl libcurl4-openssl-dev libxml2-dev libboost-dev libboost-filesystem-dev libboost-system-dev libboost-program-options-dev libdmalloc-dev libdmalloc5 libgoogle-perftools-dev libgoogle-perftools4 libboost-regex-dev python-virtualenv python-libxml2 libxslt1-dev libipfix-dev libipfix protobuf-compiler libprotobuf-dev python-pycassa python-cassandra-driver python-cassandra python-cassandra cassandra-tools cassandra-cpp-driver cassandra-cpp-driver-dev cassandra-cpp-driver-dev  libnetty-java libjavassist-java python-subunit subunit google-perftools

# Stop cassandra
/etc/init.d/cassandra stop

#export
export KERNELDIR=/lib/modules/$(basename `ls -d /lib/modules/*|tail -1`)/build
export RTE_KERNELDIR=${KERNELDIR}
#SET ENV
export JVM_VERSION=1.7

#pip install gevent
wget https://launchpad.net/ubuntu/+archive/primary/+files/python-gevent_1.1.2-1_amd64.deb 
apt-get install python-greenlet python-greenlet-dev
dpkg -i python-gevent_1.1.2-1_amd64.deb

time sudo scons --root=`pwd` --kernel-dir=$KERNELDIR install
#export CONTRAIL_BUILD_JOBS=18
time sudo scons -k --root=`pwd` --kernel-dir=$KERNELDIR test

#copy log files
mkdir -p logs/"$(date '+%d-%b-%Y')"
find build/ -name test.log -exec cp --parents --target-directory=logs/"$(date '+%d-%b-%Y')" {} \;

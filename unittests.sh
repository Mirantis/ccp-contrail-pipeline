#!/bin/bash

# Downloads the package lists from the repositories
apt-get update -y
# Install all needed dependencies for Opencontrail
cd src/build/packages/
for d in */ ; do echo "$d"; cd $d; mk-build-deps -t "apt-get -o Debug::pkgProblemResolver=yes -y" -i debian/control; dpkg -i $d*.deb; cd ../ ; done
cd ../../
# Install all needed dependencies for Unittest "scons tests"
apt-get -y install flex bison libboost-python-dev google-mock libgtest-dev liblog4cplus-dev libtbb-dev curl libcurl4-openssl-dev libxml2-dev libboost-dev libboost-filesystem-dev libboost-system-dev libboost-program-options-dev libdmalloc-dev libdmalloc5 libgoogle-perftools-dev libgoogle-perftools4 libboost-regex-dev python-virtualenv python-libxml2 libxslt1-dev libipfix-dev libipfix protobuf-compiler libprotobuf-dev python-pycassa python-cassandra-driver python-cassandra python-cassandra cassandra-tools cassandra-cpp-driver cassandra-cpp-driver-dev cassandra-cpp-driver-dev
#Run unit tests
scons tests

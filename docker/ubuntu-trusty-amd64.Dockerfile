FROM ubuntu:trusty

ARG artifactory_url
ARG timestamp
ARG uid=1000

ENV ARTIFACTORY_URL $artifactory_url
ENV TIMESTAMP $timestamp
ENV JENKINS_UID $uid

## Configure APT mirror
RUN [ "x${ARTIFACTORY_URL}" != "x" ] && ( \
        apt-get update \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https wget \
        && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
        && echo | openssl s_client -showcerts -connect `echo $ARTIFACTORY_URL | cut -d '/' -f 3` 2>/dev/null | awk '/BEGIN CERTIFICATE/{print;flag=1;next}/END CERTIFICATE/{print;flag=0}flag' >/usr/local/share/ca-certificates/artifactory.crt \
        && update-ca-certificates \
        && echo "deb ${ARTIFACTORY_URL}/in-ubuntu-${TIMESTAMP} trusty main restricted universe" >/etc/apt/sources.list \
        && echo "deb ${ARTIFACTORY_URL}/in-ubuntu-${TIMESTAMP} trusty-updates main restricted universe" >>/etc/apt/sources.list \
        && wget -O - ${ARTIFACTORY_URL}/in-tcpcloud-apt-${TIMESTAMP}/public.gpg | apt-key add - \
        && echo "deb ${ARTIFACTORY_URL}/in-tcpcloud-apt-${TIMESTAMP}/nightly/ trusty extra tcp" >>/etc/apt/sources.list \
    ) || ( \
        apt-get update \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https wget \
        && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
        && wget -O - http://apt.tcpcloud.eu/public.gpg | apt-key add - \
        && echo "deb http://apt.tcpcloud.eu/nightly/ trusty extra tcp" >>/etc/apt/sources.list \
    )

# Install requirements for Contrail build
RUN apt-get update && apt-get install -y \
        linux-headers-generic \
        build-essential \
        git \
        vim-nox \
        wget \
        scons \
        libxml2-utils \
        python-lxml \
        autoconf \
        automake \
        libtool \
        patch \
        unzip \
        pkg-config \
        javahelper \
        ant \
        python-setuptools \
        python-nose \
        sudo \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN useradd -s /bin/bash --uid $JENKINS_UID -m jenkins
RUN echo "ALL    ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

ENV USER jenkins

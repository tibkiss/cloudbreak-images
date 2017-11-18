FROM centos:7
MAINTAINER Hortonworks

RUN echo root:password | chpasswd

RUN yum install epel-release -y && yum clean all
RUN yum update -y && yum clean all

#Setting up systemd
ENV container docker
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;

RUN yum install -y systemd* && yum clean all

RUN yum install -y yum-utils yum-plugin-ovl tar git curl bind-utils unzip wget gcc net-tools sudo zip && yum clean all

RUN yum install -y openssh-server openssh-clients && yum clean all
RUN systemctl enable sshd

# initscripts (service wrapper for servicectl) is need othewise the Ambari is unable to start postgresql
RUN yum install -y initscripts && yum clean all

RUN curl -o /usr/bin/jq http://stedolan.github.io/jq/download/linux64/jq && chmod +x /usr/bin/jq

ADD docker/etc/yum.conf /etc/yum.conf

ADD docker/systemd/pam.d_sshd /etc/pam.d/sshd
RUN chmod 644 /etc/pam.d/sshd

ENV PS1 "[\u@cloudbreak \W]# "

RUN mkdir -p /bootstrap /bootstrap/logs
ADD docker/systemd/centos7-systemd.sh /bootstrap/
ADD docker/systemd/start-systemd.c /bootstrap/
RUN gcc /bootstrap/start-systemd.c -o /bootstrap/start-systemd && \
    chgrp -v nobody /bootstrap/start-systemd && \
    chmod 4050 /bootstrap/start-systemd

# Use systemctl-replacement during saltstack highstate
ENV SYSTEMCTL_REPLACEMENT=https://raw.githubusercontent.com/tibkiss/docker-systemctl-replacement/06367e13d96fed16447c2ed6dd1979d559e7f9a5/files/docker/systemctl.py
ADD ${SYSTEMCTL_REPLACEMENT} /usr/bin
RUN chmod 755 /usr/bin/$(basename ${SYSTEMCTL_REPLACEMENT}) && \
    mv /usr/bin/systemctl /usr/bin/systemctl.orig && \
    ln -sf /usr/bin/systemctl.py /usr/bin/systemctl

ADD /saltstack /tmp/saltstack
ADD /docker/saltstack_grains /tmp/saltstack/base/salt/_grains
ADD /docker/saltstack_grains /tmp/saltstack/hortonworks/salt/_grains
ADD /scripts/salt-install.sh /tmp/saltstack/
ADD /scripts/salt-setup.sh /tmp/saltstack/
ENV SALT_REPO_URL=https://repo.saltstack.com/yum/redhat/salt-repo-2017.7-1.el7.noarch.rpm
ADD ${SALT_REPO_URL} /tmp/saltstack
RUN /tmp/saltstack/salt-install.sh centos /tmp/saltstack/$(basename ${SALT_REPO_URL})
RUN /tmp/saltstack/salt-setup.sh base

# restore systemctl to system default
RUN ln -sf /usr/bin/systemctl.orig /usr/bin/systemctl

ENV TERM linux
VOLUME [ "/sys/fs/cgroup" ]

CMD ["/bootstrap/start-systemd"]

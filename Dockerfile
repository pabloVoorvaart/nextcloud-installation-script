
FROM ubuntu:18.04

RUN apt-get update && \
    apt-get -y install python2.7-minimal sudo systemd gawk sed jq tar unzip git curl wget redir socat traceroute haproxy rsync && \
    curl -o get-pip.py https://bootstrap.pypa.io/get-pip.py && python2.7 get-pip.py && rm get-pip.py && \
    pip --no-cache-dir install awscli httpie yq

RUN git clone https://github.com/pabloVoorvaart/nextcloud-installation-script.git
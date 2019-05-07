
FROM ubuntu:18.04

RUN apt-get update && \
    apt-get -y install apt-utils python3.6-minimal sudo gawk sed jq tar unzip git curl wget \
    redir socat traceroute haproxy rsync python-pip

#RUN git clone https://github.com/pabloVoorvaart/nextcloud-installation-script.git

#docker run -it -p 8080:8080 ubuntu-utils /bin/bash
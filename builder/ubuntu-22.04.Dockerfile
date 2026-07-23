FROM ubuntu:22.04 AS builder

RUN apt-get update && \
    apt upgrade -y

RUN ls

RUN ./ipxe/bin/build.sh install_dependencies

ENTRYPOINT [ "/bin/bash" ]

FROM ubuntu:26.04 AS builder

RUN apt-get update && \
    apt upgrade -y

WORKDIR /platform-build

COPY . .

RUN ./ipxe/bin/build.sh install_dependencies

ENTRYPOINT [ "/bin/bash" ]
